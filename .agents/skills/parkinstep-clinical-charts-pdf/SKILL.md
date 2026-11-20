---
name: parkinstep-clinical-charts-pdf
description: >-
  Implements Parkinson's gait clinical analytics charts using fl_chart (120s FoG
  probability timeline, 0.5-3 Hz vs 3-7.35 Hz FFT Freeze Index spectrum, ON/OFF
  Levodopa medication trends) and the A4 clinical PDF/CSV report exporter for
  neurologists. Use when building screens S-09 or S-10 or any report export feature.
---

# ParkinStep Clinical Charts & Neurologist Report Builder

Skill ini memandu pembuatan visualisasi analitik sesi (**S-09**) & tren longitudinal (**S-10**) dengan `fl_chart`, serta generator laporan **PDF A4 & CSV** untuk dokter saraf.

---

## Langkah 1 — Muat Blueprint Grafik & Laporan PDF

Baca [charts_and_pdf_blueprint.md](./references/charts_and_pdf_blueprint.md) untuk memastikan formula skor terkalibrasi, skala sumbu, pita frekuensi FFT, *Medical Disclaimer* baku, dan tata letak PDF terpenuhi.

## Langkah 2 — Bangun 3 Grafik Ramah Sentuh Tremor (`fl_chart`)

1. **`FogTimelineChart` (`S-09`):** Grafik garis `0..120 detik` untuk `calibratedScore` (`0–100%`), garis batas horizontal putus-putus pada **`50%`** (`thr_val`), dan blok vertikal berarsir `#EF4444` (alpha `0.20`) pada tiap episode FoG terkonfirmasi (`min_run >= 2`).
2. **`SpectralFreezeIndexChart` (`S-09`):** Grafik batang perbandingan **Energi Lokomotor (`0,5–3,0 Hz`, `#22D399`)** vs **Energi Tremor FoG (`3,0–7,35 Hz` @ 15 Hz, `#EF4444`)**, menampilkan angka **Moore's Freeze Index** dan status **Asimetri Engkel Kiri–Kanan**.
3. **`MedicationTrendChart` (`S-10`):** Tren multi-sesi `FoG%` yang membedakan sesi **`ON` Obat (`#00A9EC`)**, **`OFF` Obat (`#F59E0B`)**, dan **`UNKNOWN` (`#475569`)**.
4. **Aturan Interaksi Anti-Tremor:** Dilarang menaruh aksi penting yang menuntut *hover* atau *pinch-zoom*; gunakan tap besar pada episode chip/baris untuk membuka kartu detail episode.

## Langkah 3 — Implementasikan Ekspor PDF & CSV (`lib/infrastructure/export/`)

1. Gunakan port `ReportExportPort` di `lib/application/ports/` dan implementasikan `ClinicalPdfExporter` (`package:pdf`) serta `ClinicalCsvExporter` (`package:csv`).
2. Sertakan header logo monokrom **`assets/branding/parkinstep_mono_clinical.svg` (`#234085`)** dan footer wajib **Medical Disclaimer** berbahasa Indonesia verbatim dari [charts_and_pdf_blueprint.md](./references/charts_and_pdf_blueprint.md).
3. Pastikan PDF dan CSV dapat diekspor **100% offline** dan dibagikan via system share sheet.

## Langkah 4 — Uji Kasus Batas Klinis (*Clinical Edge-Cases*)

Wajib uji minimal 2 kasus ekstrem dari dataset test resmi:
- **Zero Episode (`PDFE10_1`):** `episode_count == 0`, grafik tetap rapi dengan status *"Tidak Terdeteksi Episode FoG"*, tidak memicu `NaN` atau pembagian nol pada `median_episode_duration_sec`.
- **Severe Continuous FoG (`PDFE01_1`, 96.6%):** Timeline terisi blok episode hampir penuh, tabel daftar episode tidak meluap keluar batas halaman PDF A4.

## Langkah 5 — Verifikasi

```bash
python3 .agents/skills/parkinstep-a11y-auditor/scripts/audit_flutter_ui.py lib/presentation && flutter test
```
