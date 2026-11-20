# Product Requirements Document (PRD) — ParkinStep (Mobile-FOG)

> **Status Dokumen:** Draft Final Pre-Development (v1.0)  
> **Tanggal:** 2026-11-20  
> **Repositori Terkait:** `Front-End-FP-Biomedic-ParkinStep` (Frontend Mobile) & `../FP-BIOMEDIC---Parkinson-Mobile-FOG` (ML Research Pipeline)  
> **Catatan UI/UX:** Spesifikasi visual & ergonomi antarmuka pada [UI_UX_SPEC.md](./UI_UX_SPEC.md) (v1.0 — Selaras Referensi Beats Medical di `contoh/` + Konsep Logo A).

---

## 1. Ringkasan Eksekutif & Konteks Klinis

**ParkinStep** adalah aplikasi mobile pendamping pasien penyakit Parkinson (*Parkinson's Disease / PD*) berbasis *Edge-AI* untuk mendeteksi episode **Freezing of Gait (FoG)** (*"kaki membeku"* secara mendadak) menggunakan **kamera smartphone monokular standar** tanpa kewajiban sensor *wearable* tambahan.

### Latar Belakang Masalah
- **Urgensi Klinis:** FoG memicu sekitar **60% kejadian jatuh** pada pasien PD (di mana 45–68% pasien mengalami jatuh per tahun) dan dialami oleh ~20% pasien tahap awal hingga ~90% pasien tahap lanjut. Episode FoG paling sering muncul saat pasien berputar arah di tempat (*turning-in-place*), ditandai dengan kaki terasa terkunci di lantai dan getaran lutut/engkel berfrekuensi **3–8 Hz** (berbeda dari jalan normal **0,5–3 Hz**).
- **Kesenjangan Layanan Kesehatan di Indonesia & Asia Tenggara:** Rasio dokter spesialis saraf di Asia Tenggara hanya **0,3 neurolog per 100.000 penduduk** (20× lebih langka dibanding Pasifik Barat), sementara 70% negara Asia telah memanfaatkan telemedicine (Mohamed Ibrahim et al., 2025). Studi lokal di Karo, Sumatera Utara (Lubis & Hasanah, 2025) juga menunjukkan 35,3% petani sayur terpapar pestisida positif skrining Parkinsonisme.
- **Proposisi Nilai ParkinStep:** Menggantikan kebutuhan sensor kaki IMU rumah sakit yang mahal dengan **kamera HP 720p @ 15 FPS** yang dijalankan secara **100% *offline-first* di perangkat**, dipadukan dengan *cueing* anti-beku (*Rhythmic Auditory Stimulation*) dan pelaporan klinis terstruktur untuk dokter saraf.

---

## 2. Tujuan Produk & Metrik Keberhasilan

| Kategori | Tujuan Produk | Metrik Keberhasilan Target (KPI) |
| :--- | :--- | :--- |
| **Klinis / Akurasi** | Mendeteksi FoG setara dengan performa model riset terbaik (`B_15hz LightGBM+FFT` & `Pure_Bi-Mamba` / `Light_ST-GCN`) tanpa degradasi akibat konversi mobile | Parity fitur & probabilitas mode *Post-Session* `< 1e-4` (FP32) terhadap 14 trial Test Set (`F1_pp >= 0.63`, `ROC-AUC >= 0.86`) |
| **Real-Time Edge** | Menjalankan ekstraksi pose + DSP + klasifikasi secara stabil pada HP Android kelas menengah Indonesia | Throughput `>= 15 FPS` (`< 66 ms/frame` rata-rata), latensi pemicuan audio cue `< 150 ms` pasca-konfirmasi window |
| **Ketahanan Lapangan** | Berfungsi penuh di daerah minim internet (puskesmas/rumah pedesaan) | `100%` fitur akuisisi, inferensi, cueing, dan riwayat lokal berfungsi dalam *Airplane Mode* |
| **Privasi & Keamanan** | Melindungi privasi visual pasien & kepatuhan UU PDP | `0` video mentah disimpan/diunggah secara default (*Privacy-Preserving Skeleton Only Mode*) |

---

## 3. Persona Pengguna & *User Journeys*

### Persona 1 — Pasien Parkinson / Lansia (`PATIENT`)
- **Profil:** Usia 55–80 tahun, mengalami tremor tangan, bradikinesia, atau episode FoG saat berputar. Tidak nyaman memakai perangkat ber-kabel.
- **Kebutuhan:** Instruksi suara Bahasa Indonesia yang jelas, tombol besar/minim gestur rumit, sistem *cueing* ritmis otomatis saat kaki terkunci, serta perlindungan keselamatan fisik saat berputar.
- **Alur Utama:** Buka aplikasi → pilih mode tes / pemantauan → konfirmasi checklist keamanan lantai → berdiri diam 3–5 detik (kalibrasi) → putar 360° bergantian kanan–kiri mengikuti panduan suara selama 2 menit → terima *cueing* otomatis jika terjadi FoG → lihat ringkasan sederhana.

### Persona 2 — Caregiver / Pendamping Keluarga / Kader Kesehatan (`CAREGIVER`)
- **Profil:** Anggota keluarga atau kader puskesmas yang memegang ponsel/tripod 2–3 meter di depan pasien, mengatur pencahayaan, dan mengawal keselamatan fisik pasien.
- **Kebutuhan:** Panduan framing kamera agar seluruh tungkai bawah (`Hip–Knee–Ankle`) masuk frame tanpa pendamping ikut terpilih sebagai subjek utama, indikator kualitas tangkapan real-time, catatan jadwal konsumsi obat Levodopa, dan tombol ekspor laporan untuk kontrol poli saraf.

### Persona 3 — Dokter Spesialis Saraf (`CLINICIAN`)
- **Profil:** Neurolog di rumah sakit rujukan atau layanan telemedicine yang menerima pasien dari daerah.
- **Kebutuhan:** Ringkasan objektif antar-kunjungan berupa persentase waktu FoG (`FoG%`), jumlah & median durasi episode, perbandingan performa saat **ON-Medication vs OFF-Medication**, serta indikator spektral (*Moore's Freeze Index* 3–8 Hz vs 0,5–3 Hz) dan asimetri kiri–kanan dalam format PDF/CSV.

---

## 4. Ruang Lingkup Produk: MVP vs Fase 2

### 4.1 Ruang Lingkup MVP (*Must-Have* Sebelum Rilis Pertama)
1. **Protokol Tes Terpandu *360° Turning-in-Place* (2 Menit):** Framing kamera setinggi tungkai bawah, *Main-Person Lock* agar asisten di frame tidak terpilih, indikator kualitas `LB6 Confidence >= 0.20`, fase kalibrasi berdiri diam `3–5 detik`, serta panduan audio TTS Bahasa Indonesia selama 120 detik.
2. **Dual Inference Mode On-Device (`B_15hz`):**
   - **Mode *Post-Session Exact*:** Memproses seluruh rekaman sesi 2 menit dengan logika batch identik notebook (`parkinsonfp-biomed.ipynb`) untuk menghasilkan skor klinis beresolusi presisi.
   - **Mode *Live Causal Cueing*:** Memproses stream kamera `15 FPS` menggunakan kalibrasi berdiri awal + ring buffer kausal 30 frame (`2.0 s`, stride `1.0 s`) + lookahead 3 frame (`200 ms`) untuk memicu intervensi real-time.
3. **Engine Classifier & Explainability Ringan:** Primary classifier **`LightGBM+FFT` (`B_15hz`, 126 fitur, `thr = 0.26`)** + opsi verifikasi deep learning **`Light_ST-GCN` (`B_15hz`, 38.801 params)** atau **`Pure_Bi-Mamba` (`B_15hz`, 212.289 params)**, lengkap dengan ekstraksi nilai *Moore's Freeze Index* & asimetri kaki.
4. **Sistem *Two-Tier Cueing* & Keselamatan Jatuh:**
   - *Tier 1 (Early Warning):* 1 window positif (`p >= thr`).
   - *Tier 2 (Confirmed FoG, `min_run >= 2` window berurutan):* Pemicuan **Auditory RAS** (metronom ritmis adaptif + voice prompt tenang), **Haptic Cueing**, dan sinyal visual (*detail tampilan mengikuti `docs/UI_UX_SPEC.md`*).
   - *Fall / Prolonged Freeze Guard:* Deteksi freeze `> 15 detik` atau penurunan drastis posisi vertikal `y_hip` dengan hitung mundur 10 detik menuju alert kontak darurat caregiver.
5. **Pelacakan Medikasi Levodopa (*ON vs OFF*) & Riwayat Offline-First:** Pencatatan status minum obat sebelum tes, penyimpanan lokal terenkripsi (`SQLCipher`), grafik riwayat sesi, dan ekspor laporan **PDF** serta **CSV**.
6. **Mode Privasi Ketat (*Zero Raw-Video Retention*):** Default tidak menyimpan video MP4 secara permanen; hanya menyimpan koordinat sendi LB6 anonim + metrik hasil.

### 4.2 Di Luar Ruang Lingkup MVP (*Fase 2 / Future Roadmap*)
- Pairing sensor wearable IMU 6-aksis eksternal via **Bluetooth Low Energy (BLE)** pada 128 Hz untuk studi validasi rumah sakit (*Scenario F oracle comparison*).
- Dukungan topologi 10 sendi tungkai bawah **LB10** (+ tumit & jari kaki) dengan model estimator lebih besar (DWPose-m / MediaPipe).
- Telekonsultasi video sinkron real-time di dalam aplikasi dan integrasi langsung ke SIMRS/SATUSEHAT FHIR.
- *Cloud Video Fallback* penuh (pengunggahan video mentah untuk diproses server bila HP sangat lawas) — pada MVP dibatasi pada sinkronisasi *skeleton keypoints* & hasil ringkasan.

---

## 5. Kebutuhan Fungsional (*Functional Requirements*)

| ID | Kebutuhan Fungsional | Kriteria Penerimaan (*Acceptance Criteria*) |
| :--- | :--- | :--- |
| **FR-01** | **Pre-Flight Safety & Kalibrasi Framing** | Tes tidak dapat dimulai sebelum user mencentang checklist keselamatan lantai. Kamera menampilkan status `LB6 Confidence` (`>= 0.20` = siap) dan memvalidasi sendi `L/R_Hip, L/R_Knee, L/R_Ankle` terdeteksi selama minimal 2 detik sebelum timer kalibrasi 3–5 detik berjalan. |
| **FR-02** | **Seleksi Subjek Utama Anti-Caregiver** | Apabila terdapat `> 1` orang dalam frame, sistem wajib memilih tepat 1 subjek pasien menggunakan formula pembobotan `area * conf * center_penalty` yang identik dengan `_yolo_extract_worker.py`, tidak berpindah-pindah secara liar ke caregiver di tepi frame. |
| **FR-03** | **Ekstraksi Pose & DSP Skenario `B_15hz`** | Sistem melakukan subsampling stream ke `15 Hz`, menjalankan `YOLO26n-Pose` (`640×640`, `det_conf=0.25`), interpolasi keypoint `conf < 0.20`, filter Hampel (`w=7, sigma=3.0`), normalisasi pelvis/leg-length, dan membentuk window `[9, 30, 6]` setiap `1.0 s`. |
| **FR-04** | **Inferensi Classifier & Debounce `min_run=2`** | Sistem mengumpankan `X` *unscaled* (126 fitur FFT/kinematik) ke `LightGBM+FFT` (atau `X_scaled` ke `Light_ST-GCN` / `Pure_Bi-Mamba`), membandingkan probabilitas terhadap `thr_val`, dan mengonfirmasi episode FoG hanya jika terjadi `>= 2` window positif berurutan. |
| **FR-05** | **Multi-Modal RAS Cueing & Stop Hysteresis** | Saat *Tier 2 Confirmed FoG* aktif, metronom audio RAS + instruksi suara + getaran haptic menyala dalam `< 150 ms`. Cueing berhenti otomatis setelah terdapat `>= 2` window `NORMAL` berturut-turut atau jika user menekan tombol *Stop*. |
| **FR-06** | **Fall / Prolonged Freeze Guard** | Jika episode FoG bertahan `> 15 detik` atau terjadi anomali drop koordinat pinggul + imobilitas, sistem memicu alarm konfirmasi `10 detik`; jika tidak dibatalkan pasien/caregiver, sistem mengirim notifikasi darurat (via API jika online, atau SMS/intent darurat perangkat jika offline). |
| **FR-07** | **Log Medikasi ON/OFF & Riwayat Longitudinal** | Sebelum/sesudah tes, user dapat mencatat nama obat, dosis, jam minum terakhir, dan status `ON` / `OFF` / `UNKNOWN`. Riwayat menampilkan perbandingan `FoG%` dan jumlah episode antar sesi `ON` vs `OFF`. |
| **FR-08** | **Ekspor Laporan Klinis & Sinkronisasi Offline** | User dapat mengekspor laporan 1 sesi atau tren multi-sesi ke file PDF dan CSV secara offline. Data sesi otomatis masuk ke antrean `sync_outbox` terenkripsi untuk dikirim ke backend saat koneksi tersedia. |

---

## 6. Kebutuhan Non-Fungsional (*Non-Functional Requirements*)

| Aspek | Target Minimum Produksi | Cara Verifikasi |
| :--- | :--- | :--- |
| **Performa Inferensi** | Rata-rata waktu pemrosesan total (YUV→RGB + YOLO26n + DSP + Classifier) `< 66 ms/frame` (`>= 15 FPS`), p95 `< 80 ms` pada Android mid-range (Snapdragon 680 / Helio G99, RAM 4 GB) | Profiling Android Perfetto selama 120 detik kontinu |
| **Latensi & Jitter Audio RAS** | Jitter antar ketukan metronom `< 20 ms`; waktu mulai suara setelah konfirmasi `< 150 ms` | Pengukuran loopback audio & timestamp event log |
| **Efisiensi Memori & Baterai** | RAM puncak `< 350 MB`; konsumsi baterai `< 8%` per sesi 2 menit; kenaikan suhu perangkat `< +6°C` setelah 3 sesi berturut-turut | Battery Historian & thermal sensor log |
| **Ukuran Aplikasi** | Installer awal (APK/IPA) `< 45 MB` (termasuk `yolo26n-pose` ~4–8 MB FP16 + `lgbm_b15hz` `< 250 KB`) | Build artifact inspection |
| **Ketersediaan Offline** | `100%` alur inti (kamera, AI, cueing, simpan riwayat, ekspor PDF) berjalan tanpa internet | Automated Airplane Mode E2E test |
| **Keamanan & Privasi** | Database lokal terenkripsi AES-256 (SQLCipher); *zero raw-video retention* default; TLS 1.3 + *certificate pinning* untuk sync | Security audit & static code scan |

---

## 7. Referensi & Ketergantungan Dokumen Lain

- **Kontrak Matematika & Ekspor Model:** [EDGE_ML_SPEC.md](./EDGE_ML_SPEC.md)
- **Arsitektur Internal & Concurrency:** [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Privasi Data (UU PDP) & Keselamatan Klinis:** [DATA_PRIVACY_AND_CLINICAL_SAFETY.md](./DATA_PRIVACY_AND_CLINICAL_SAFETY.md)
- **Kontrak API Backend & WebSocket:** [API_CONTRACT.md](./API_CONTRACT.md)
- **Penyimpanan Lokal & Sinkronisasi:** [LOCAL_STORAGE_AND_SYNC.md](./LOCAL_STORAGE_AND_SYNC.md)
- **Rencana Pengujian & Benchmark 14 Trial:** [TESTING_AND_BENCHMARK_PLAN.md](./TESTING_AND_BENCHMARK_PLAN.md)
- **Spesifikasi UI/UX & Aksesibilitas:** [UI_UX_SPEC.md](./UI_UX_SPEC.md) (v1.0 — Selaras Referensi `contoh/`)
- **Aturan Pengembangan & Guardrails Agent:** [AGENT_RULES.md](../AGENT_RULES.md)
