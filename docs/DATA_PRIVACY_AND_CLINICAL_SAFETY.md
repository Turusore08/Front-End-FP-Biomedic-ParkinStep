# Spesifikasi Privasi Data & Keselamatan Klinis — ParkinStep (Mobile-FOG)

> **Status Dokumen:** Wajib Dipatuhi Sebelum Implementasi (v1.0)  
> **Tanggal:** 2026-11-20  
> **Lingkup Regulasi:** UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi (UU PDP Indonesia) & Praktik Keselamatan Pasien Telemedicine  

---

## 1. Klasifikasi Klinis & Batasan Tanggung Jawab Medis

### 1.1 Status Aplikasi
**ParkinStep** diklasifikasikan sebagai **alat bantu skrining dini, pemantauan gaya berjalan berbasis rumah, dan penyedia *cueing* ritmis (*assistive & wellness screening tool*)**. Aplikasi ini **BUKAN** perangkat diagnosis medis (*diagnostic Software as a Medical Device / SaMD*) dan **TIDAK menggantikan** evaluasi tatap muka dokter spesialis saraf (*neurologist*).

### 1.2 Keterbatasan Ilmiah yang Wajib Dikomunikasikan
Berdasarkan hasil audit teknis pipeline `FP-BIOMEDIC---Parkinson-Mobile-FOG`, sistem memiliki batasan objektif berikut:
1. **Sensitivitas & Spesifisitas Tidak 100%:** Model utama `LightGBM+FFT (B_15hz)` memiliki *sensitivity* `60.26%` dan *specificity* `93.53%` pada held-out test set (dan `75.23%` / `87.28%` pada audit parsial 27/35-fold LOSO), artinya **episode FoG ringan/singkat berpotensi terlewat (*false negative*)** dan gerakan memutar cepat/pencahayaan buruk berpotensi memicu **alarm palsu (*false positive*)**.
2. **Batas Topologi 17 COCO Keypoints:** `YOLO26n-Pose` memodelkan sendi kaki hingga pergelangan kaki (*ankle*), belum membaca ujung jari kaki/tumit (*toe/heel*) secara langsung.
3. **Ketergantungan Kondisi Visual:** Kualitas prediksi menurun apabila tungkai bawah tertutup pakaian panjang longgar/rok panjang, terhalang furnitur, atau berada dalam pencahayaan redup.

### 1.3 Teks *Medical Disclaimer* Baku (Wajib Muncul di Onboarding, Layar Hasil & Footer PDF)
> **"PERHATIAN MEDIS: ParkinStep merupakan alat bantu skrining dan pemantauan mandiri gejala *Freezing of Gait* (FoG) berbasis kecerdasan buatan. Hasil deteksi, skor indeks, dan grafik pada aplikasi ini BUKAN merupakan diagnosis medis resmi dan tidak dapat dijadikan dasar perubahan dosis obat tanpa persetujuan dokter spesialis saraf. Jika pasien mengalami jatuh, cedera, atau gejala memburuk secara mendadak, segera hubungi tenaga medis atau layanan gawat darurat setempat."**

---

## 2. Kepatuhan UU No. 27 Tahun 2022 (UU PDP Indonesia)

Dalam UU PDP Pasal 4 ayat (2), **data dan informasi kesehatan** serta **data biometrik/rekaman video tubuh** termasuk **Data Pribadi yang Bersifat Spesifik** yang memerlukan perlindungan paling ketat.

### 2.1 Klasifikasi Data Aplikasi

| Jenis Data | Kategori UU PDP | Lokasi Penyimpanan Default | Kebijakan Retensi & Enkripsi |
| :--- | :--- | :--- | :--- |
| **Video Kamera Mentah (`.mp4` / frame YUV)** | Data Biometrik / Visual Spesifik | **RAM-only** (Live) atau **Cache Terenkripsi Sementara** (Post-Session) | **Zero Raw-Video Retention:** Dihapus otomatis (`secure delete`) segera setelah ekstraksi keypoint LB6 selesai (`<= 5 menit`). |
| **Koordinat Skeleton LB6 (`T × 6 × 3`)** | Data Kinematika Medis Spesifik | SQLite terenkripsi **SQLCipher (AES-256)** di perangkat | Tidak memuat wajah/identitas visual; hanya diunggah ke cloud jika user memberi opt-in eksplisit. |
| **Riwayat Sesi, Episode FoG & Log Obat** | Data Kesehatan Spesifik | SQLCipher lokal + Cloud (opsional) | Enkripsi saat istirahat (*at-rest*) & saat transmisi (*in-transit* TLS 1.3). |
| **Identitas Pasien & Kontak Darurat** | Data Pribadi Umum & Kontak | SQLCipher lokal + Keystore/Keychain | Hanya profil minimum (*data minimization*): nama inisial/panggilan, tahun lahir, kontak darurat. |

### 2.2 Mekanisme *Granular Opt-In Informed Consent*
Aplikasi dilarang menggunakan persetujuan tunggal (*bundled consent*). Pengguna wajib diberikan **3 saklar persetujuan terpisah** pada saat onboarding (dan dapat dicabut kapan saja di menu Pengaturan Privasi):
1. **Consent Wajib (Operasional Lokal):** Izin pemrosesan kamera di perangkat untuk menghasilkan deteksi FoG dan menyimpan riwayat secara lokal di HP.
2. **Consent Opsional A (Sinkronisasi Telemedicine Anonim):** Izin mengunggah koordinat skeleton LB6 + metrik hasil sesi + log medikasi ke server dokter/caregiver (tanpa video).
3. **Consent Opsional B (Audit Kualitas / Cloud Fallback):** Default **OFF**. Hanya aktif jika pengguna secara sadar menyetujui pengiriman sementara klip video saat inferensi lokal gagal, dengan jaminan penghapusan otomatis di server segera setelah pemrosesan (`auto_delete_after_inference = true`).

### 2.3 Hak Subjek Data
- **Hak Akses & Portabilitas:** User dapat mengekspor seluruh riwayat sesi & log obat ke format terbuka (`CSV` & `PDF`) kapan saja secara offline.
- **Hak Penghapusan Permanen (*Right to Erasure*):** Tersedia tombol *"Hapus Semua Data Saya"* yang menghapus seluruh tabel SQLCipher lokal, menghapus kunci enkripsi di Keystore/Keychain, menghapus cache media, serta mengirim permintaan penghapusan akun & data ke `DELETE /api/v1/patients/{patient_id}` bila terhubung ke cloud.

---

## 3. Kebijakan *Zero Raw-Video Retention* & Minimisasi Data

1. **Mode Live Streaming:** Frame `YUV_420_888` / `CVPixelBuffer` dikirim langsung ke memori C++ `YOLO26n-Pose` dan **langsung dibuang (*overwrite/release*)** setelah tensor keypoint `17×3` diekstrak. Tidak ada file video yang pernah ditulis ke penyimpanan eksternal/galeri HP.
2. **Mode Post-Session (Rekam 2 Menit lalu Analisis Batch):**
   - Rekaman sementara ditulis ke direktori sandbox internal aplikasi (*App Private Storage*, bukan galeri publik), dienkripsi atau dibatasi aksesnya.
   - Segera setelah proses batch menghasilkan koordinat LB6 dan skor window, file video sementara **wajib dihapus permanen** (*zero-fill* atau `unlink` + verifikasi tidak ada file sisa pada lifecycle `onDestroy`/`app startup cleanup`).
   - Pengecualian hanya berlaku jika user secara eksplisit menekan tombol *"Simpan Video ke Perangkat untuk Dokter"* disertai peringatan privasi.
3. **Larangan Kebocoran ke Log & Telemetry:** Crash reporter (mis. Sentry/Firebase Crashlytics) dan logger konsol rilis **DILARANG** mencatat koordinat pose mentah, nama pasien, nomor telepon kontak darurat, path file video, maupun token JWT.

---

## 4. Protokol Keselamatan Fisik Tes *360° Turning-in-Place*

Karena berputar 360° di tempat justru merupakan manuver pemicu FoG dan risiko jatuh tertinggi pada pasien Parkinson, aplikasi wajib menegakkan protokol keselamatan fisik berikut sebelum mengizinkan perekaman dimulai:

### 4.1 *Pre-Flight Safety Checklist* (Wajib Konfirmasi Sebelum Sesi)
Aplikasi harus menampilkan daftar periksa singkat yang wajib dikonfirmasi oleh pasien/caregiver sebelum membuka kamera tes:
1. **Lingkungan Lantai Aman:** Lantai kering, tidak licin, dan bebas dari kabel, karpet terlipat, atau barang berserakan.
2. **Ruang Gerak Bebas:** Tersedia ruang bebas minimal radius `1,5 meter` di sekeliling pasien.
3. **Penopang / Pendamping Siap:** Disarankan ada caregiver pendamping di luar pusat frame (atau kursi kokoh/dinding di dekat jangkauan) sebagai penopang bila pasien kehilangan keseimbangan.
4. **Alas Kaki & Pakaian:** Pasien mengenakan alas kaki datar tidak licin (atau bertelanjang kaki di permukaan aman) serta pakaian yang memperlihatkan area pinggul, lutut, dan pergelangan kaki agar keypoint LB6 terbaca akurat.

### 4.2 Guardrail Audio Cueing Selama Tes
- Instruksi suara TTS tidak boleh memerintahkan gerakan cepat atau mendadak. Tempo suara harus tenang, jelas, dan berjarak aman (*"Silakan berputar perlahan ke kanan... sekarang berhenti sejenak..."*).
- Apabila `LB6 Confidence` turun di bawah `0.20` secara kontinu `> 3 detik`, aplikasi memutar peringatan suara lembut agar pendamping mengecek posisi kamera, bukan meminta pasien membungkuk atau mengatur HP sambil berdiri tidak stabil.

---

## 5. Protokol Eskalasi Darurat (*Fall & Prolonged Freeze Guard*)

### 5.1 Kondisi Pemicu Eskalasi
Sistem memicu protokol penjaga keselamatan bila salah satu kondisi berikut terpenuhi selama sesi aktif:
1. **Prolonged Freeze Guard:** Episode FoG terkonfirmasi (`min_run >= 2`) bertahan secara kontinu melebihi **15 detik** (atau `>= 14` window positif berurutan tanpa pemulihan).
2. **Indikasi Jatuh (*Sudden Hip Vertical Drop + Immobility*):** Terjadi penurunan mendadak koordinat `y` rata-rata `L_Hip` & `R_Hip` melampaui ambang batas proporsi `leg_length` terkalibrasi (mis. perpindahan ke bawah `> 0.65 * leg_length` dalam `<= 1.0 detik`) diikuti hilangnya/berhentinya gerakan tungkai selama `>= 3 detik`.

### 5.2 Mekanisme *Anti-False-Alarm* & Eskalasi
1. **Fase Konfirmasi (10 Detik):** Aplikasi menghentikan tes sementara, membunyikan nada perhatian yang jelas, memunculkan prompt suara *"Apakah Anda baik-baik saja? Tekan layar atau ucapkan 'Aman' dalam 10 detik"* dengan timer hitung mundur visual.
2. **Pembatalan:** Jika user/caregiver menekan tombol pembatalan (*"Saya Baik-Baik Saja"*) atau perintah suara pembatalan dalam 10 detik, status darurat dibatalkan dan dicatat sebagai *near-miss / false-alarm log*.
3. **Eksekusi Darurat:** Jika hitung mundur 10 detik habis tanpa respons:
   - Apabila **online**: aplikasi segera memanggil `POST /api/v1/alerts/emergency` untuk mengirim *push notification* prioritas tinggi ke aplikasi caregiver yang tertaut.
   - Apabila **offline**: aplikasi membunyikan sirine lokal yang dapat didengar penghuni rumah serta menyiapkan/membuka aksi SMS darurat perangkat (sesuai izin OS yang telah disetujui saat onboarding) ke nomor kontak darurat utama.

---

## 6. Kontrol Keamanan Teknis Aplikasi (*Security Baseline*)

| Lapisan | Kontrol Keamanan Wajib |
| :--- | :--- |
| **Penyimpanan Kunci** | Kunci enkripsi DB SQLCipher & JWT Refresh Token wajib disimpan di Android Keystore / iOS Keychain (`flutter_secure_storage`). |
| **Enkripsi Data Lokal** | Seluruh tabel pasien, riwayat sesi, dan blob skeleton dienkripsi AES-256 via `SQLCipher`. |
| **Keamanan Jaringan** | Komunikasi API hanya via `HTTPS` (TLS 1.2/1.3) & `WSS` dengan *Certificate Pinning* pada build rilis. |
| **Integritas Model Edge** | Setiap file model ONNX/LightGBM yang diunduh via OTA wajib diverifikasi hash `SHA-256`-nya terhadap `/api/v1/models/manifest` sebelum dieksekusi oleh C++ runtime. |
| **Rahasia & Konfigurasi** | Dilarang keras menyimpan *API key*, *signing secret*, atau URL internal sensitif di dalam source code atau Git. |
