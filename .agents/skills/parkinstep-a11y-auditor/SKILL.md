---
name: parkinstep-a11y-auditor
description: >-
  Audits ParkinStep Flutter UI code for Parkinson's motor accessibility (large hit
  targets >= 56-64 dp, zero thin sliders/swipes), WCAG 2.1 contrast compliance,
  font scaling 1.5x at 360x640 dp, Clean Architecture layer boundaries, and brand
  leakage prevention. Use before merging any UI screen or widget PR.
---

# ParkinStep Accessibility & UI Architecture Auditor

Skill ini bertindak sebagai *Quality Gate* otomatis dan manual sebelum kode antarmuka **ParkinStep** di `lib/presentation/` digabungkan (*merge*).

---

## Langkah 1 — Jalankan Skrip Audit Statis Otomatis

Jalankan validator Python bawaan pada folder UI Flutter:

```bash
python3 .agents/skills/parkinstep-a11y-auditor/scripts/audit_flutter_ui.py lib/presentation
```

Skrip memeriksa secara deterministik:
1. **Clean Architecture Boundary:** Melarang import `dart:ffi`, `package:drift`, `package:dio`, atau `/infrastructure/` di dalam `lib/presentation/`.
2. **Anti-Tremor Widgets:** Mendeteksi pemakaian `Slider`, `RangeSlider`, atau `Dismissible` yang sulit bagi penderita tremor.
3. **WCAG 2.1 Contrast Guard:** Mendeteksi warna teks `#00A9EC` (`2.66:1` di atas putih) atau `#1AEAD8` (`1.52:1`) tanpa penanda latar gelap `// dark-bg-ok`.
4. **Minimum Font Size & Brand Leakage:** Mendeteksi `fontSize < 14.0` dan sisa string merek referensi `Beats Medical` / `"Nine Hole Peg"`.

## Langkah 2 — Periksa Checklist Ergonomi & Visual Lengkap

Buka [a11y_checklist.md](./references/a11y_checklist.md) untuk mengaudit item yang memerlukan verifikasi semantik/test:
- Target sentuh (`56 dp` minimum, `64–72 dp` CTA/list tiles, `84 dp` tombol batal Fall Guard) & celah `>= 16 dp`.
- Redundansi multi-sensori (*warna + ikon + label teks*).
- Teks *Medical Disclaimer* baku hadir di onboarding, ringkasan hasil, dan footer PDF.

## Langkah 3 — Jalankan Widget Test Skala 1.5× & Delegasi `flutter_a11y_agent`

1. Tambahkan/jalankan test layout pada viewport kecil **`360 × 640 dp`** dengan **`TextScaler.linear(1.5)`** menggunakan template di [a11y_checklist.md](./references/a11y_checklist.md) untuk memastikan nol `RenderFlex overflow`.
2. Jika melakukan review menyeluruh lintas banyak layar Flutter, delegasikan pemeriksaan lanjutan ke subagent **`flutter_a11y_agent`** untuk memeriksa *Semantics tree* dan dukungan TalkBack/VoiceOver.

## Langkah 4 — Susun Laporan Audit

Klasifikasikan seluruh temuan secara tegas:
- **`BLOCKER` (Wajib Perbaiki Sebelum Merge):** Pelanggaran Clean Architecture, kontras WCAG `< 4.5:1` pada teks, adanya `Slider`/`Dismissible` di alur pasien, target sentuh `< 48 dp`, overflow di `1.5×`, atau bocornya logo/string `Beats Medical`.
- **`WARNING` (Perlu Tindak Lanjut):** Target sentuh `48–55 dp` atau label `Semantics` kurang deskriptif.
