---
name: parkinstep-design-system
description: >-
  Implements and maintains the ParkinStep Flutter design system, Figma design tokens,
  and 10 Beats-Medical-inspired reusable UI components adapted for Parkinson's patients.
  Use this skill whenever creating or updating theme files, ColorScheme/ThemeExtension
  tokens, reusable buttons/cards/gauges/metronome widgets, or syncing component variables
  to Figma according to docs/UI_UX_SPEC.md.
---

# ParkinStep Design System & Component Builder

Skill ini mengunci keseragaman visual **ParkinStep** di Flutter dan Figma agar konsisten dengan referensi Beats Medical di `contoh/`, memenuhi ergonomi anti-tremor, serta memakai identitas merek **Konsep A (`P+S`)**.

---

## Langkah 1 — Muat Token & Katalog Komponen Resmi

Sebelum membuat atau mengedit widget UI maupun library Figma, baca [tokens_and_components.md](./references/tokens_and_components.md) serta verifikasi sumber kebenaran di [UI_UX_SPEC.md](../../../docs/UI_UX_SPEC.md).

## Langkah 2 — Terapkan Theme & Design Tokens Flutter

1. Tempatkan seluruh token di `lib/presentation/theme/`:
   - `app_colors.dart` (konstanta warna `#0B1B2B`, `#234085`, `#00A9EC`, `#0077B6`, `#1AEAD8`, `#D8F1FC`, `#E8F7FC`, `#FFFFFF`, `#F8FAFC`, `#475569`, `#CBD5E1`, serta semantic `#22D399`, `#F59E0B`, `#EF4444`).
   - `app_typography.dart` (`Plus Jakarta Sans` / `Nunito` dengan `FontFeature.tabularFigures()` untuk timer/BPM/skor; ukuran body minimum `16 sp`, dilarang `< 14 sp`).
   - `app_theme.dart` (`ThemeData` light & dark canvas dengan `ThemeExtension<ParkinThemeExt>`).
2. Jika menyinkronkan ke **Figma**, muat skill `figma-generate-library` + `figma-use` terlebih dahulu dan ikuti pemetaan variabel pada [tokens_and_components.md](./references/tokens_and_components.md).

## Langkah 3 — Bangun 10 Komponen Standar di `lib/presentation/widgets/design_system/`

Dilarang menduplikasi styling tombol atau kartu di layar (`S-01`–`S-10`). Wajib memakai komponen standar:
- `ParkinPrimaryPillButton`, `ParkinSecondaryIceButton`, `ParkinVerticalFeatureCard`, `ParkinStackedMenuTile`
- `ParkinPulseMetronomeRing`, `ParkinRiskGauge`, `ParkinHighlightPrompt`, `ParkinProgressPill`
- `ParkinDarkReminderCard`, `ParkinSessionCarouselCard`

## Langkah 4 — Terapkan Guardrail Aksesibilitas & Merek

1. **WCAG Contrast:** Jangan gunakan `vibrantAzure` (`#00A9EC`) atau `rhythmAqua` (`#1AEAD8`) sebagai warna teks di atas `#FFFFFF`; pakai `royalNavy` (`#234085`) atau `accessibleAzure` (`#0077B6`).
2. **Anti-Tremor Ergonomics:** Target sentuh `>= 56 dp` (`>= 64 dp` untuk CTA/menu tile), jarak celah `>= 16 dp`, tidak ada `Slider` tipis atau *horizontal swipe*.
3. **Integritas Merek:** Gunakan aset **Konsep A** di `assets/branding/`, dilarang menjiplak teks/ikon `BM`, `"Nine Hole Peg"`, atau string contoh Beats Medical.

## Langkah 5 — Verifikasi Wajib

Jalankan validasi statis dan auditor aksesibilitas proyek sebelum selesai:

```bash
python3 .agents/skills/parkinstep-a11y-auditor/scripts/audit_flutter_ui.py lib/presentation && dart analyze
```
