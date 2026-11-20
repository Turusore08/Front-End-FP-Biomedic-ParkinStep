# Rencana Pengujian, Paritas Numerik & Benchmark Perangkat — ParkinStep

> **Status Dokumen:** Standar Verifikasi & QA Wajib Lulus Rilis (v1.0)  
> **Tanggal:** 2026-11-20  
> **Sumber Golden Fixtures:** `../FP-BIOMEDIC---Parkinson-Mobile-FOG/Data/Train Val Test/test/` & `output/mobilefog_rhama/02_processed_scenarios/D_windowed_stgcn_cls/from_B_denoised_hampel_accel_15hz/test.npz`

---

## 1. Piramida Pengujian & Gerbang Kualitas (*Quality Gates*)

| Level Uji | Target Cakupan | Tooling | Syarat Lulus (*Gate*) |
| :--- | :--- | :--- | :--- |
| **1. Unit Test Domain & FSM** | Entitas domain, FSM transisi sesi, hysteresis cueing, Fall Guard | `flutter_test` | `100%` branch FSM & rule klinis teruji |
| **2. C++ DSP & Model Parity** | `yuv_letterbox`, `_select_main_person`, `lb6_preprocessor`, `fft_features_126`, ONNX / LGBM | `GoogleTest` + Python reference script | Selisih fitur 126-dim & probabilitas **`< 1e-4`** (FP32) |
| **3. Golden Test-Set Regression** | Seluruh **14 trial Test Set (`1.652` window)** | Automated C++ CLI Runner | Replikasi metrik Test Set `results_summary.csv` (`F1_pp >= 0.63` utk `LightGBM+FFT`) |
| **4. API Contract & DB Sync** | OpenAPI 3.1 DTO serialization, Outbox retry, SQLCipher | `mocktail` / `oasdiff` | `0` breaking drift; zero data loss saat Airplane Mode |
| **5. Device & Thermal Benchmark** | Performa kamera 15 FPS, RAM, baterai, audio RAS jitter | Android Perfetto / Xcode Instruments | FPS `>= 15`, frame latency `< 66 ms`, RAM `< 350 MB` |

---

## 2. *Golden-Fixture Numerical Parity Suite* (14 Trial Test Set Resmi)

Implementasi C++ (`native/parkinstep_core/`) wajib diverifikasi langsung terhadap **seluruh 14 file video/pose Test Set `B_15hz`** (`1.652` window, `307` window FoG = `18.58%` berdasarkan label `y_maj`):

| Trial ID | Subjek | Total Window (`B_15hz`) | Window FoG (`y_maj`) | Persentase FoG | Skenario Pengujian Spesifik yang Diwakili |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `PDFE01_1` | `01` | 118 | 114 | `96.6%` | **Severe Continuous FoG:** Uji konsistensi trigger cueing & prolonged freeze guard `> 15s` |
| `PDFE01_2` | `01` | 118 | 114 | `96.6%` | **Severe FoG + IMU Boundary:** Video 2,2–3,0 s lebih panjang dari IMU (`inside_imu_mask = 0` di ujung akhir) |
| `PDFE06_1` | `06` | 118 | 2 | `1.7%` | **Short FoG Episode:** Uji sensitivitas episode pendek tepat di batas `min_run = 2` |
| `PDFE06_2` | `06` | 118 | 0 | `0.0%` | **Negative Control:** Uji spesifisitas tinggi (zero false cueing) |
| `PDFE10_1` | `10` | 118 | 0 | `0.0%` | **Negative Control:** Uji stabilitas putaran normal 360° tanpa alarm |
| `PDFE10_2` | `10` | 118 | 0 | `0.0%` | **Negative Control + IMU Boundary:** Uji pemotongan akhir video yang lebih panjang dari IMU |
| `PDFE16_1` | `16` | 118 | 33 | `28.0%` | **Intermittent FoG + Caregiver-in-Frame:** Ada asisten klinis di tepi kanan frame (menguji `_select_main_person`) |
| `PDFE16_2` | `16` | 118 | 7 | `5.9%` | **Mild/Moderate Intermittent FoG:** Uji transisi masuk-keluar episode berulang |
| `PDFE23_1` | `23` | 118 | 11 | `9.3%` | **Intermittent FoG:** Uji stabilitas akurasi multi-episode |
| `PDFE23_2` | `23` | 118 | 0 | `0.0%` | **Same-Subject Normal Trial:** Memastikan model tidak bias ke identitas subjek `23` |
| `PDFE24_1` | `24` | 118 | 25 | `21.2%` | **Moderate FoG:** Uji akurasi durasi episode & *Moore's Freeze Index* |
| `PDFE32_1` | `32` | 118 | 1 | `0.8%` | **Single-Window Boundary:** Hanya 1 window positif — menjadi uji wajib filter debounce `min_run = 2` |
| `PDFE32_2` | `32` | 118 | 0 | `0.0%` | **Negative Control:** Uji spesifisitas pada subjek `32` |
| `PDFE32_3` | `32` | 118 | 0 | `0.0%` | **Negative Control:** Uji spesifisitas pada subjek `32` |
| **TOTAL** | **7 Subjek** | **1.652** | **307** | **`18.58%`** | **Replikasi Resmi Held-Out Test Set (`results_summary.csv`)** |

### Kriteria Kelulusan Paritas (*Pass/Fail Thresholds*)
1. **Stage 2 & 3 (DSP & 126 Fitur FFT):** Menggunakan input keypoint `01_extracted_poses_raw/yolo26n_rhama/test/*.npz`, implementasi C++ *Mode Post-Session Batch* wajib menghasilkan vektor 126 fitur dengan **`max_abs_diff < 1e-4`** terhadap fungsi Python `extract_fft_kinematic_features`.
2. **Stage 4 (Inference `LightGBM+FFT`, `Light_ST-GCN`, `Pure_Bi-Mamba`):** Selisih probabilitas mentah antara ONNX Runtime C++ vs PyTorch/LightGBM Python **wajib `< 1e-4`** untuk FP32, dan jika memakai kuantisasi FP16 pada `YOLO26n-Pose`, degradasi metrik akhir pada 14 video test tidak boleh melebihi **`ΔPR-AUC <= 0.015`** dan **`ΔF1_pp <= 0.015`**.
3. **Verifikasi Mode Causal Streaming:** Seluruh 14 video diputar secara berurutan frame-per-frame (`15 Hz`) memakai fase kalibrasi `3–5 detik` awal; dicatat selisih antara *Mode Causal* vs *Mode Batch Exact* (target `ΔF1_pp <= 0.04`).

---

## 3. Matriks Benchmark Perangkat & Performa (*Device Profiling*)

Aplikasi wajib lolos uji profil selama **3 sesi berturut-turut (3 × 2 menit = 6 menit kontinu)** pada tiga kelas perangkat target berikut:

| Tier Perangkat Target | Spesifikasi Representatif | Target FPS Efektif | Latency Rata-Rata / p95 | RAM Puncak | Baterai / Sesi 2 Menit | Kenaikan Suhu |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Tier 1 — Android Entry** | RAM 4 GB, Snapdragon 680 / Helio G85 (CPU XNNPACK) | `>= 15 FPS` | `< 65 ms` / `< 85 ms` | `< 350 MB` | `< 9%` | `< +7°C` |
| **Tier 2 — Android Mid-Range** | RAM 6–8 GB, Snapdragon 7xx / Dimensity 700+ | `>= 15 FPS` (stabil) | `< 45 ms` / `< 60 ms` | `< 320 MB` | `< 7%` | `< +5°C` |
| **Tier 3 — iOS** | iPhone 12+ (CoreML / Neural Engine) | `>= 15 FPS` (stabil) | `< 25 ms` / `< 35 ms` | `< 280 MB` | `< 5%` | `< +4°C` |

**Metrik Tambahan yang Wajib Diukur:**
- **Jitter Audio Metronom RAS:** Diukur dengan perekaman audio eksternal / timestamp callback audio; simpangan baku interval antar-ketukan wajib **`< 20 ms`**.
- **Overhead Render Skeleton HUD:** Main UI thread Flutter tetap berada pada budget **`< 16.6 ms/frame`** (60 FPS) di atas Impeller.

---

## 4. Uji *Edge-Case* Lapangan & Keamanan

| Skenario Uji Lapangan | Perilaku Sistem yang Diharapkan |
| :--- | :--- |
| **Asisten Klinis / Anggota Keluarga Berdiri di Tepi Frame** | `_select_main_person` mengunci pasien di tengah frame; tidak terjadi loncatan bounding box ke asisten. |
| **Pasien Berputar 180° Membelakangi Kamera (Oklusi Sebagian)** | Titik dengan `conf < 0.20` terinterpolasi mulus; tidak memicu `NaN` atau lonjakan probabilitas palsu akibat koordinat `(0,0)`. |
| **Pencahayaan Ruangan Redup / Kamera Tertutup Kain** | `LB6 Conf < 0.20` terdeteksi; aplikasi memunculkan peringatan kualitas tanpa crash dan menandai `low_quality_flag = 1`. |
| **Aplikasi Dimatikan Paksa (*Kill*) di Tengah Analisis** | File video sementara yang belum sempat dihapus otomatis dibersihkan oleh `VideoDisposalService` saat aplikasi dibuka kembali. |
| **Panggilan Telepon Masuk Saat Tes Berjalan** | Kamera & metronom berhenti aman tanpa *hardware lock leak*, state sesi tersimpan rapi. |
| **Airplane Mode Penuh (7 Hari Berturut-Turut)** | Puluhan sesi tes + log obat tersimpan terenkripsi di SQLCipher; saat internet dinyalakan kembali, seluruh antrean `sync_outbox` terkirim tanpa duplikasi (*idempotent*). |
