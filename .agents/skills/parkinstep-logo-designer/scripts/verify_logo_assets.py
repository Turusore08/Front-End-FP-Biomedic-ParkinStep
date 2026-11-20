#!/usr/bin/env python3
"""Validate ParkinStep SVG/PNG branding assets and WCAG 2.1 contrast ratios."""

from __future__ import annotations

import argparse
import glob
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PARKINSTEP_PALETTE = {
    "Deep Midnight Navy": "#0B1B2B",
    "Clinical Royal Navy": "#234085",
    "Primary Vibrant Azure": "#00A9EC",
    "Rhythm Aqua": "#1AEAD8",
    "Soft Ice Surface": "#D8F1FC",
    "Clinical White": "#FFFFFF",
}


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"Invalid hex color: {hex_color}")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    def channel(c: int) -> float:
        s = c / 255.0
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4

    r, g, b = rgb
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(hex_a: str, hex_b: str) -> float:
    l1 = relative_luminance(hex_to_rgb(hex_a))
    l2 = relative_luminance(hex_to_rgb(hex_b))
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def wcag_grade(ratio: float) -> str:
    if ratio >= 7.0:
        return "AAA (Text & UI)"
    if ratio >= 4.5:
        return "AA (Normal Text)"
    if ratio >= 3.0:
        return "AA-Large / UI Graphical (>=3:1)"
    return "FAIL (<3:1 - Do not use as text on this bg)"


def print_palette_audit() -> None:
    print("=== ParkinStep Palette WCAG 2.1 Contrast Audit ===")
    backgrounds = [("White #FFFFFF", "#FFFFFF"), ("Midnight #0B1B2B", "#0B1B2B")]
    for bg_name, bg_hex in backgrounds:
        print(f"\nBackground: {bg_name}")
        for name, fg_hex in PARKINSTEP_PALETTE.items():
            if fg_hex.upper() == bg_hex.upper():
                continue
            r = contrast_ratio(fg_hex, bg_hex)
            print(f"  - {name:24s} ({fg_hex}) -> {r:5.2f}:1  [{wcag_grade(r)}]")


def validate_svg(path: Path) -> tuple[bool, list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    raw = path.read_text(encoding="utf-8", errors="replace")
    if "data:image/" in raw.lower():
        errors.append("Contains embedded raster image (data:image/); master logo must be pure vector.")
    if re.search(r"<\s*script\b", raw, re.IGNORECASE) or re.search(r"\bon\w+\s*=", raw, re.IGNORECASE):
        errors.append("Contains <script> or inline event handler (forbidden for security).")

    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        errors.append(f"Invalid XML: {exc}")
        return False, errors, warnings

    root = tree.getroot()
    tag = root.tag.split("}")[-1]
    if tag != "svg":
        errors.append(f"Root element is <{tag}>, expected <svg>.")

    vb = root.attrib.get("viewBox")
    if not vb:
        errors.append("Missing required 'viewBox' attribute.")
    else:
        parts = vb.replace(",", " ").split()
        if len(parts) != 4:
            errors.append(f"Invalid viewBox '{vb}', expected 4 numbers.")
        else:
            try:
                _, _, vw, vh = [float(x) for x in parts]
                if vw <= 0 or vh <= 0:
                    errors.append(f"viewBox width/height must be positive: {vw}x{vh}")
                elif "icon" in path.stem.lower() and abs(vw - vh) > 1e-3:
                    errors.append(f"Icon SVG should have 1:1 square viewBox, found {vw}x{vh}")
            except ValueError:
                errors.append(f"Non-numeric values in viewBox '{vb}'.")

    has_text = any(el.tag.split("}")[-1] in ("text", "tspan") for el in root.iter())
    if has_text and "icon" in path.stem.lower():
        warnings.append("Icon SVG contains raw <text>; convert letters to <path> for cross-OS consistency.")

    has_shapes = any(
        el.tag.split("}")[-1] in ("path", "circle", "rect", "ellipse", "polygon", "polyline")
        for el in root.iter()
    )
    if not has_shapes:
        errors.append("No vector geometry primitives (<path>, <circle>, <rect>, etc.) found.")

    return len(errors) == 0, errors, warnings


def read_png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        header = f.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a valid PNG signature.")
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def validate_png(path: Path) -> tuple[bool, list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        w, h = read_png_dimensions(path)
    except ValueError as exc:
        return False, [str(exc)], warnings

    if "icon" in path.stem.lower() or "master" in path.stem.lower():
        if w != h:
            errors.append(f"Icon PNG must be square (1:1), found {w}x{h}.")
        if w < 512:
            errors.append(f"Icon PNG too small ({w}x{h}); minimum 512x512 required (1024x1024 recommended).")
        elif w < 1024:
            warnings.append(f"Icon PNG is {w}x{h}; 1024x1024 is recommended for App Store / Play Store master.")
    return len(errors) == 0, errors, warnings


def expand_inputs(patterns: list[str]) -> list[Path]:
    resolved: list[Path] = []
    for pat in patterns:
        matches = glob.glob(pat)
        if matches:
            resolved.extend(Path(m) for m in sorted(matches))
        else:
            resolved.append(Path(pat))
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate ParkinStep SVG/PNG logo assets and palette contrast.")
    parser.add_argument("files", nargs="*", help="SVG or PNG files (supports globs).")
    parser.add_argument("--check-palette", action="store_true", help="Print WCAG 2.1 contrast audit for brand palette.")
    args = parser.parse_args()

    if args.check_palette:
        print_palette_audit()

    if not args.files:
        return 0 if args.check_palette else 1

    paths = expand_inputs(args.files)
    all_ok = True
    print("\n=== Asset Validation ===")
    for p in paths:
        if not p.exists():
            print(f"[FAIL] {p}: file not found")
            all_ok = False
            continue
        ext = p.suffix.lower()
        if ext == ".svg":
            ok, errs, warns = validate_svg(p)
        elif ext == ".png":
            ok, errs, warns = validate_png(p)
        else:
            print(f"[SKIP] {p}: unsupported extension '{ext}'")
            continue

        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {p}")
        for w in warns:
            print(f"  WARN : {w}")
        for e in errs:
            print(f"  ERROR: {e}")
        if not ok:
            all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
