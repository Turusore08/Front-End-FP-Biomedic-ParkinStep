# AGENT_RULES.md — Panduan Rekayasa & Guardrails Pengembangan ParkinStep

Dokumen ini mengikat seluruh kontributor manusia maupun *AI coding agent* yang bekerja di dalam repositori `Front-End-FP-Biomedic-ParkinStep`.

---

## 1. Sumber Kebenaran & Status Dokumen Spesifikasi

Sebelum membuat atau mengubah kode fitur apa pun, wajib merujuk dokumen berikut:
- Ringkasan Arsitektur & Analisis Sistem: [analisis.md](./analisis.md)
- Kebutuhan Produk: [docs/PRD.md](./docs/PRD.md)
- Privasi & Keselamatan Klinis: [docs/DATA_PRIVACY_AND_CLINICAL_SAFETY.md](./docs/DATA_PRIVACY_AND_CLINICAL_SAFETY.md)
- Kontrak Matematika & Edge-ML: [docs/EDGE_ML_SPEC.md](./docs/EDGE_ML_SPEC.md)
- Arsitektur Aplikasi & Concurrency: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)
- Kontrak API Backend & WebSocket: [docs/API_CONTRACT.md](./docs/API_CONTRACT.md)
- Skema DB Terenkripsi & Sync Offline: [docs/LOCAL_STORAGE_AND_SYNC.md](./docs/LOCAL_STORAGE_AND_SYNC.md)
- Rencana Pengujian & Paritas 14 Trial: [docs/TESTING_AND_BENCHMARK_PLAN.md](./docs/TESTING_AND_BENCHMARK_PLAN.md)
- Spesifikasi UI/UX: [docs/UI_UX_SPEC.md](./docs/UI_UX_SPEC.md)

> **ATURAN KHUSUS `docs/UI_UX_SPEC.md`:**  
> Seluruh implementasi antarmuka, komponen desain, token warna (`#0B1B2B`, `#234085`, `#00A9EC`, `#0077B6`, `#1AEAD8`, `#D8F1FC`), aksesibilitas tremor (`>= 56–64 dp`, tanpa slider/swipe wajib), serta *Live Skeleton HUD* wajib mengikuti [docs/UI_UX_SPEC.md](./docs/UI_UX_SPEC.md) yang selaras dengan referensi `contoh/` dan memakai identitas merek **Konsep A (`P+S` Kinetic Stride)**. Dilarang meniru logo `BM` atau elemen non-ParkinStep dari screenshot referensi.

---

## 2. Invarian Edge-ML & DSP Biomedis (DILARANG DIUBAH SEPIHAK)

Konstanta dan perilaku berikut berasal langsung dari kode pelatihan `../FP-BIOMEDIC---Parkinson-Mobile-FOG` dan **tidak boleh diubah tanpa pelatihan ulang model, pembaruan manifest OTA, dan kelulusan *Golden Parity Test***:

1. **Topologi LB6:** Indeks COCO tetap `[11, 12, 13, 14, 15, 16]` (`L_Hip, R_Hip, L_Knee, R_Knee, L_Ankle, R_Ankle`).
2. **Threshold & Filter DSP:** `DET_CONF = 0.25`, `CONF_VALID_THRES = 0.20`, `HAMPEL_WINDOW = 7`, `HAMPEL_SIGMA = 3.0`, `WINDOW_SEC = 2.0` (`T=30 @ 15Hz`), `STRIDE_SEC = 1.0`, `MIN_RUN_WINDOWS = 2`.
3. **Butterworth Rule:** Filter *Butterworth 9 Hz* **TIDAK BOLEH** dijalankan pada profil produksi `15 Hz` (sesuai syarat kode `if fs >= 25.0`).
4. **Input Scaling per Model:**
   - `LightGBM+FFT` **WAJIB** menerima **`X` mentah (UNSCALED)** + **126 fitur** dengan **`ddof = 0`** dan bin FFT freeze `3.5–7.0 Hz` (`bin 7..14` @ `15 Hz`).
   - `Light_ST-GCN`, `Pure_Bi-Mamba`, dan `Hybrid_GCN+BiMamba` **WAJIB** menerima **`X_scaled`** menggunakan `scaler_mean` & `scaler_std` dari `ModelManifest` aktif.
5. **Larangan Edit Repo Saudara:** Repositori `../FP-BIOMEDIC---Parkinson-Mobile-FOG` adalah referensi *read-only* bagi pengembangan frontend — jangan mengubah file riset di sana dari dalam tugas frontend kecuali diminta secara eksplisit.

---

## 3. Aturan Clean Architecture & Kualitas Kode

1. **The Dependency Rule:**
   - `lib/domain/` **DILARANG** mengimpor `flutter/*`, `dart:ffi`, `drift`, `dio`, `riverpod`, atau library pihak ketiga mana pun.
   - Seluruh akses ke native C++, kamera, database lokal, audio RAS, dan jaringan API **WAJIB** melewati abstract port/interface di `lib/application/ports/`.
2. **Isolasi Logika DSP & UI:**
   - Dilarang keras menulis logika matematika sinyal (`FFT`, `Hampel`, `normalisasi tulang`) di dalam file widget UI atau controller Dart jika modul C++ `native/parkinstep_core/` tersedia.
3. **Strict Type Safety:**
   - Aktifkan aturan analyzer Dart paling ketat (`strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`).
   - Dilarang memakai `dynamic` (kecuali pada fungsi parsing JSON tervalidasi di layer `infrastructure/`) dan dilarang mengabaikan null-safety (`!` tanpa guard).
4. **DRY, Modular & Terstruktur:**
   - Fungsi harus kecil, fokus tunggal, menggunakan *early return*, dan tidak menduplikasi logika antar layar/platform.

---

## 4. Aturan Keamanan, Privasi & Integritas Kontrak

1. **Zero Hardcoded Secrets:** Dilarang menuliskan API key, client secret, URL staging/prod sensitif, atau passphrase SQLCipher di dalam kode atau commit Git. Gunakan `--dart-define` / `.env` yang ada di `.gitignore`.
2. **Privacy by Default (UU PDP):**
   - Dilarang menyimpan file `.mp4` mentah ke galeri publik atau membiarkan video sementara bertahan sesudah analisis selesai tanpa opt-in eksplisit.
   - Dilarang mencetak koordinat pose mentah, nama pasien, nomor telepon darurat, atau JWT ke `print`/`debugPrint`/Crashlytics.
3. **API Contract Parity:**
   - Semua field tanggal/waktu lintas API dan DB lokal wajib **UTC ISO-8601 (`...Z`)**.
   - Semua enum JSON wajib menggunakan **String Enum**, bukan integer.
   - Setiap mutasi `POST` offline-sync wajib membawa `Idempotency-Key` (UUIDv7).

---

## 5. Alur Kerja Git & Verifikasi

1. **Conventional Commits:** Gunakan format `<type>(<scope>): <description>`, contoh:
   - `docs(spec): tambahkan blueprint PRD dan kontrak Edge-ML`
   - `feat(edge-dsp): implementasi 126 fitur FFT C++ untuk LightGBM`
   - `fix(cueing): perbaiki hysteresis stop metronom RAS`
2. **Syarat Sebelum Commit / Merge:**
   - `dart analyze` bebas warning/error.
   - `flutter test` seluruh unit & FSM test lulus.
   - Perubahan apa pun di `native/parkinstep_core/` wajib lulus `ctest` / GoogleTest Golden Parity terhadap fixture `14` video test set.
