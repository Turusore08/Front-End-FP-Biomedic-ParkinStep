# Blueprint Grafik Klinis `fl_chart` & Laporan PDF Neurolog — ParkinStep

Referensi teknis untuk implementasi layar **S-09**, **S-10**, dan `ClinicalPdfExporter` / `ClinicalCsvExporter` sesuai [EDGE_ML_SPEC.md](../../../../docs/EDGE_ML_SPEC.md), [UI_UX_SPEC.md](../../../../docs/UI_UX_SPEC.md), dan [DATA_PRIVACY_AND_CLINICAL_SAFETY.md](../../../../docs/DATA_PRIVACY_AND_CLINICAL_SAFETY.md).

---

## 1. Kalibrasi Skor Risiko untuk Visualisasi UI

Karena ambang batas model riset berada di angka rendah (`thr_val = 0.26` untuk `B_15hz LightGBM+FFT`, `0.39` untuk `Light_ST-GCN`, `0.15` untuk `Pure_Bi-Mamba`), grafik timeline **wajib** memakai **Skor Terkalibrasi `0–100%`** dengan titik pivot `50% == thr_val`:

```dart
double calibrateRiskScore(double rawProb, double thrVal) {
  final p = rawProb.clamp(0.0, 1.0);
  if (p < thrVal) {
    return 50.0 * (p / math.max(thrVal, 1e-6));
  }
  return 50.0 + 50.0 * ((p - thrVal) / math.max(1.0 - thrVal, 1e-6));
}
```

---

## 2. Spesifikasi 3 Grafik `fl_chart`

### Grafik 1 — `FogTimelineChart` (`S-09`)
- **Sumbu X:** Waktu sesi `0 .. duration_sec` (interval label `20 s`, font `12 sp` `#234085`).
- **Sumbu Y:** Skor Risiko FoG Terkalibrasi `0 .. 100%` (label `0%, 50%, 100%`).
- **Garis Ambang:** `HorizontalLine(y: 50, color: Color(0xFF234085), dashArray: [6, 4])` berlabel `"Batas FoG"`.
- **Blok Episode Terkonfirmasi:** `VerticalRangeAnnotation` warna `#EF4444` opacity `0.18` untuk setiap `FogEpisodeItem` (`min_run >= 2`).
- **Empty State (`episode_count == 0`, mis. `PDFE10_1`):** Garis kurva tetap digambar di bawah `50%` dengan badge hijau: *"Tidak Terdeteksi Episode FoG"*.

### Grafik 2 — `SpectralFreezeIndexChart` (`S-09`)
- **Dua Batang Utama:**
  - Batang 1 (`#22D399`): Energi Pita Lokomotor Normal (`0,5 – 3,0 Hz`, bin `1..6` @ 15 Hz).
  - Batang 2 (`#EF4444`): Energi Pita Getar FoG (`3,0 – 7,35 Hz`, bin `7..14` @ 15 Hz).
- **Kartu Metrik Pendamping di Bawah Grafik:**
  - **Moore's Freeze Index** (`log1p(e_freeze / e_loco)`) rata-rata pada periode FoG (atau seluruh sesi jika 0 episode).
  - **Asimetri Engkel Kiri–Kanan** (terkait *fitur 118* `mean(asym_v)` yang menjadi pemisah teratas pohon `lgbm_B_15hz.txt`).

### Grafik 3 — `MedicationTrendChart` (`S-10`)
- **Plot Longitudinal:** Sumbu X = tanggal sesi, Sumbu Y = `fog_percentage` (`0–100%`).
- **Pewarnaan Status Medikasi (tanpa mengandalkan warna semata — beda bentuk titik):**
  - `ON` Obat: Lingkaran `#00A9EC`
  - `OFF` Obat: Persegi/Diamond `#F59E0B`
  - `UNKNOWN`: Segitiga `#475569`

---

## 3. Tata Letak Laporan PDF A4 Dokter Saraf

Bangun di `lib/infrastructure/export/clinical_pdf_exporter.dart` (`package:pdf`):

1. **Header Klinik (Atas Halaman 1):**
   - Kiri: Aset vektor monokrom `assets/branding/parkinstep_mono_clinical.svg` (`#234085`).
   - Kanan: Judul *"Laporan Pemantauan Freezing of Gait (ParkinStep Mobile-FOG)"*, ID/Inisial Pasien, Tanggal & Jam (WIB + UTC ISO-8601), Status Obat (`ON/OFF/UNKNOWN`), serta Bundle Model (`B_15hz LightGBM+FFT`).
2. **Kotak 4 Metrik Utama:** `Durasi Sesi`, `Persentase Waktu FoG (%)`, `Jumlah Episode`, `Median Durasi Episode (detik)`.
3. **Ringkasan Grafik & Tabel Episode:**
   - Render grafik timeline (`CustomPainter` PDF vector canvas atau image high-DPI `300 dpi`) + ringkasan *Moore's Freeze Index*.
   - Tabel berpaginasi otomatis (`pw.TableHelper.fromTextArray` agar aman bila episode banyak seperti `PDFE01_1`): `Episode # | Mulai (s) | Selesai (s) | Durasi (s) | Skor Puncak (%)`.
4. **Footer Wajib di Setiap Halaman (*Medical Disclaimer* Verbatim):**
   > *"PERHATIAN MEDIS: ParkinStep merupakan alat bantu skrining dan pemantauan mandiri gejala Freezing of Gait (FoG) berbasis kecerdasan buatan. Hasil deteksi, skor indeks, dan grafik pada aplikasi ini BUKAN merupakan diagnosis medis resmi dan tidak dapat dijadikan dasar perubahan dosis obat tanpa persetujuan dokter spesialis saraf. Jika pasien mengalami jatuh, cedera, atau gejala memburuk secara mendadak, segera hubungi tenaga medis atau layanan gawat darurat setempat."*

---

## 4. Skema Kolom Ekspor CSV (`ClinicalCsvExporter`)

Satu file CSV per sesi atau ringkasan multi-sesi memakai header UTF-8:
`session_id,patient_id,started_at_utc,med_state,classifier_used,threshold_used,window_idx,start_sec,end_sec,raw_prob,calibrated_score,pred_raw,pred_postprocessed,freeze_index_ankle,bilateral_asym_ankle,low_quality_flag`
