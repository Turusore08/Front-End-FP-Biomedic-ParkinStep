#!/usr/bin/env python3
"""Static UI architecture, Parkinson accessibility, and brand-integrity auditor for Flutter."""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

FORBIDDEN_PRESENTATION_IMPORTS = re.compile(
    r"""^\s*import\s+['"](?:dart:ffi|package:drift|package:dio|[^'"]*infrastructure/)""",
    re.MULTILINE,
)
ANTI_TREMOR_WIDGETS = re.compile(r"\b(Slider|RangeSlider|Dismissible)\s*\(")
LOW_CONTRAST_TOKENS = re.compile(
    r"(?:0xFF00A9EC|0xFF1AEAD8|\bvibrantAzure\b|\brhythmAqua\b)", re.IGNORECASE
)
FONT_SIZE_PATTERN = re.compile(r"\bfontSize\s*:\s*([0-9]+(?:\.[0-9]+)?)")
BRAND_LEAK_PATTERN = re.compile(
    r"\b(?:Beats\s+Medical|Nine\s+Hole\s+Peg|All\s+letters\s+require\s+a\s+stamp)\b",
    re.IGNORECASE,
)


@dataclass
class Finding:
    file: str
    line: int
    rule: str
    severity: str
    message: str


def audit_dart_file(path: Path) -> list[Finding]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    findings: list[Finding] = []
    norm_path = path.as_posix()

    # 1. Clean Architecture dependency check inside presentation/
    if "/presentation/" in norm_path or norm_path.startswith("presentation/"):
        for m in FORBIDDEN_PRESENTATION_IMPORTS.finditer(text):
            line_no = text[: m.start()].count("\n") + 1
            findings.append(
                Finding(
                    str(path),
                    line_no,
                    "ARCH_BOUNDARY",
                    "BLOCKER",
                    f"Forbidden infrastructure/FFI import inside presentation layer: {m.group(0).strip()}",
                )
            )

    in_textstyle = False
    textstyle_depth = 0

    for idx, line in enumerate(lines, start=1):
        # 2. Anti-tremor forbidden interactive widgets
        if ANTI_TREMOR_WIDGETS.search(line) and "a11y-exempt:" not in line:
            findings.append(
                Finding(
                    str(path),
                    idx,
                    "ANTI_TREMOR_WIDGET",
                    "BLOCKER",
                    "Avoid Slider/RangeSlider/Dismissible in Parkinson's UX; use >=56dp step buttons.",
                )
            )

        # 3. Brand leakage from reference screenshots
        if BRAND_LEAK_PATTERN.search(line):
            findings.append(
                Finding(
                    str(path),
                    idx,
                    "BRAND_LEAKAGE",
                    "BLOCKER",
                    "Reference app brand/demo text leaked into ParkinStep UI code.",
                )
            )

        # 4. Track TextStyle(...) scope for contrast & min font size
        if "TextStyle(" in line:
            in_textstyle = True
            textstyle_depth = line.count("(") - line.count(")")
        elif in_textstyle:
            textstyle_depth += line.count("(") - line.count(")")

        if in_textstyle or "TextStyle(" in line:
            m_fs = FONT_SIZE_PATTERN.search(line)
            if m_fs and "font-exempt:" not in line:
                val = float(m_fs.group(1))
                if val < 14.0:
                    findings.append(
                        Finding(
                            str(path),
                            idx,
                            "MIN_FONT_SIZE",
                            "BLOCKER",
                            f"fontSize {val} < 14.0 sp minimum for elderly Parkinson's readability.",
                        )
                    )

            if LOW_CONTRAST_TOKENS.search(line) and "color:" in line and "dark-bg-ok" not in line:
                findings.append(
                    Finding(
                        str(path),
                        idx,
                        "WCAG_LOW_CONTRAST_TEXT",
                        "BLOCKER",
                        "Do not use vibrantAzure (#00A9EC) or rhythmAqua (#1AEAD8) for text on light bg; use accessibleAzure (#0077B6) or royalNavy (#234085), or annotate '// dark-bg-ok' if on #0B1B2B.",
                    )
                )

            if textstyle_depth <= 0:
                in_textstyle = False
                textstyle_depth = 0

    return findings


def audit_target(target: Path) -> list[Finding]:
    if target.is_file():
        return audit_dart_file(target) if target.suffix == ".dart" else []
    findings: list[Finding] = []
    for dart_file in sorted(target.rglob("*.dart")):
        findings.extend(audit_dart_file(dart_file))
    return findings


def run_self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        pres = Path(tmp) / "lib" / "presentation"
        pres.mkdir(parents=True)

        bad_file = pres / "bad_screen.dart"
        bad_file.write_text(
            "\n".join(
                [
                    "import 'dart:ffi';",
                    "import 'package:flutter/material.dart';",
                    "class BadScreen extends StatelessWidget {",
                    "  Widget build(BuildContext context) {",
                    "    return Column(children: [",
                    "      Slider(value: 0.5, onChanged: (_) {}),",
                    "      Text('Beats Medical', style: TextStyle(",
                    "        color: AppColors.vibrantAzure,",
                    "        fontSize: 11,",
                    "      )),",
                    "    ]);",
                    "  }",
                    "}",
                ]
            ),
            encoding="utf-8",
        )

        good_file = pres / "good_screen.dart"
        good_file.write_text(
            "\n".join(
                [
                    "import 'package:flutter/material.dart';",
                    "class GoodScreen extends StatelessWidget {",
                    "  Widget build(BuildContext context) {",
                    "    return Column(children: [",
                    "      Text('ParkinStep', style: TextStyle(",
                    "        color: AppColors.accessibleAzure,",
                    "        fontSize: 18,",
                    "      )),",
                    "      Text('Dark Mode Accent', style: TextStyle(",
                    "        color: AppColors.rhythmAqua, // dark-bg-ok",
                    "        fontSize: 16,",
                    "      )),",
                    "    ]);",
                    "  }",
                    "}",
                ]
            ),
            encoding="utf-8",
        )

        bad_findings = audit_target(bad_file)
        bad_rules = {f.rule for f in bad_findings}
        expected_rules = {
            "ARCH_BOUNDARY",
            "ANTI_TREMOR_WIDGET",
            "BRAND_LEAKAGE",
            "WCAG_LOW_CONTRAST_TEXT",
            "MIN_FONT_SIZE",
        }
        assert bad_rules == expected_rules, f"Expected {expected_rules}, got {bad_rules}"

        good_findings = audit_target(good_file)
        assert len(good_findings) == 0, f"Expected 0 findings on good file, got {good_findings}"

    print("[SELF-TEST PASS] All 5 ParkinStep UI audit rules verified cleanly.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit ParkinStep Flutter UI files for A11y & Clean Architecture.")
    parser.add_argument("target", nargs="?", help="Path to Dart file or presentation directory (e.g., lib/presentation).")
    parser.add_argument("--self-test", action="store_true", help="Run built-in rule self-tests and exit.")
    args = parser.parse_args()

    if args.self_test:
        return run_self_test()

    if not args.target:
        parser.print_help()
        return 1

    target = Path(args.target)
    if not target.exists():
        print(f"[INFO] Target '{target}' does not exist yet (pre-scaffolding). Nothing to audit.")
        return 0

    findings = audit_target(target)
    if not findings:
        print(f"[PASS] Zero UI architecture/accessibility issues found in '{target}'.")
        return 0

    for f in findings:
        print(f"[{f.severity}] {f.file}:{f.line} ({f.rule}) -> {f.message}")
    blockers = sum(1 for f in findings if f.severity == "BLOCKER")
    print(f"\nSummary: {len(findings)} finding(s), {blockers} BLOCKER(s).")
    return 1 if blockers > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
