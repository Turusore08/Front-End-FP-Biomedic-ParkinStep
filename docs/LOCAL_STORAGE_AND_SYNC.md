# Spesifikasi Penyimpanan Lokal Terenkripsi & Sinkronisasi Offline — ParkinStep

> **Status Dokumen:** Spesifikasi Persistensi & Sync (v1.0)  
> **Tanggal:** 2026-11-20  
> **Strategi:** *Offline-First* + Enkripsi AES-256 (`SQLCipher` via `Drift`) + *Transactional Outbox*

Aplikasi **ParkinStep** harus dapat diandalkan sepenuhnya di daerah tanpa koneksi internet stabil (puskesmas/rumah pasien). Seluruh data klinis disimpan lokal lebih dulu dan disinkronkan secara asinkron ketika internet tersedia (sesuai izin consent UU PDP).

---

## 1. Keamanan & Manajemen Kunci Enkripsi Lokal

1. **Engine Database:** `SQLite` dengan ekstensi **`SQLCipher` (AES-256-CBC + HMAC-SHA512)**.
2. **Pembuatan Kunci Per Perangkat:** Saat pertama kali aplikasi dijalankan, generator RNG kriptografis (`Random.secure()`) membuat *master passphrase* 256-bit yang disimpan **eksklusif** di:
   - **Android:** Android Keystore via `flutter_secure_storage` (`EncryptedSharedPreferences` / Keystore hardware-backed).
   - **iOS:** iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
3. **Larangan Kunci Statis:** Kunci SQLCipher dilarang keras di-*hardcode* atau diturunkan secara deterministik hanya dari ID user.

---

## 2. Skema Relasional Database Lokal (DDL SQL)

```sql
-- 1. Profil Pasien Minimum (Data Minimization)
CREATE TABLE patients (
    patient_id TEXT PRIMARY KEY,              -- UUIDv4/v7
    display_name TEXT NOT NULL,
    birth_year INTEGER,
    role TEXT NOT NULL,                       -- 'PATIENT' | 'CAREGIVER' | 'CLINICIAN'
    consent_local INTEGER NOT NULL DEFAULT 1, -- 0/1
    consent_skeleton_sync INTEGER NOT NULL DEFAULT 0,
    consent_cloud_video INTEGER NOT NULL DEFAULT 0,
    updated_at_utc TEXT NOT NULL              -- ISO-8601 UTC '...Z'
);

-- 2. Kontak Darurat Caregiver
CREATE TABLE emergency_contacts (
    contact_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_e164 TEXT NOT NULL,
    relation TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,
    updated_at_utc TEXT NOT NULL
);

-- 3. Log Medikasi Levodopa (Pelacakan ON vs OFF)
CREATE TABLE medication_logs (
    log_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    drug_name TEXT NOT NULL,
    dosage_mg REAL NOT NULL,
    taken_at_utc TEXT NOT NULL,
    med_state TEXT NOT NULL,                  -- 'ON' | 'OFF' | 'UNKNOWN'
    notes TEXT,
    sync_status TEXT NOT NULL DEFAULT 'PENDING'
);

-- 4. Header Sesi Tes 360° Turning-in-Place
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    last_medication_log_id TEXT REFERENCES medication_logs(log_id),
    protocol TEXT NOT NULL,                   -- 'TURNING_360_2MIN' | 'FREE_WALK_MONITORING'
    inference_mode TEXT NOT NULL,             -- 'LIVE_CAUSAL' | 'POST_SESSION_EXACT' | 'CLOUD_FALLBACK'
    med_state TEXT NOT NULL,                  -- 'ON' | 'OFF' | 'UNKNOWN'
    classifier_used TEXT NOT NULL,            -- 'LIGHTGBM_FFT' | 'LIGHT_STGCN' | 'PURE_BIMAMBA'
    model_bundle_version TEXT NOT NULL,
    threshold_used REAL NOT NULL,
    target_fps INTEGER NOT NULL DEFAULT 15,
    started_at_utc TEXT NOT NULL,
    ended_at_utc TEXT,
    duration_sec REAL NOT NULL DEFAULT 0,
    valid_lb6_ratio REAL NOT NULL DEFAULT 0,
    fog_percentage REAL NOT NULL DEFAULT 0,
    episode_count INTEGER NOT NULL DEFAULT 0,
    total_fog_duration_sec REAL NOT NULL DEFAULT 0,
    median_episode_duration_sec REAL NOT NULL DEFAULT 0,
    safety_checklist_confirmed INTEGER NOT NULL DEFAULT 0,
    sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY' -- 'LOCAL_ONLY' | 'PENDING' | 'SYNCED'
);

-- 5. Episode FoG Terkonfirmasi (min_run >= 2)
CREATE TABLE fog_episodes (
    episode_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    episode_index INTEGER NOT NULL,
    start_sec REAL NOT NULL,
    end_sec REAL NOT NULL,
    duration_sec REAL NOT NULL,
    peak_calibrated_score REAL NOT NULL,
    mean_freeze_index REAL
);

-- 6. Prediksi Per Window (2.0 detik, Stride 1.0 detik)
CREATE TABLE window_predictions (
    session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    window_idx INTEGER NOT NULL,
    start_sec REAL NOT NULL,
    end_sec REAL NOT NULL,
    raw_prob REAL NOT NULL,
    calibrated_score REAL NOT NULL,
    pred_raw INTEGER NOT NULL,
    pred_postprocessed INTEGER NOT NULL,
    freeze_index_ankle REAL,
    bilateral_asym_ankle REAL,
    low_quality_flag INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (session_id, window_idx)
);

-- 7. Blob Keypoint LB6 Terkompresi (Tanpa Video Mentah)
CREATE TABLE skeleton_blobs (
    session_id TEXT PRIMARY KEY REFERENCES sessions(session_id) ON DELETE CASCADE,
    sampling_hz REAL NOT NULL DEFAULT 15.0,
    frame_count INTEGER NOT NULL,
    compression TEXT NOT NULL DEFAULT 'ZLIB',
    lb6_xyc_blob BLOB NOT NULL,               -- zlib(float32[T, 6, 3]) + int64[T] timestamps
    byte_size INTEGER NOT NULL
);

-- 8. Registry Bundle Model Edge OTA Lokal
CREATE TABLE model_bundles (
    bundle_version TEXT PRIMARY KEY,
    manifest_json TEXT NOT NULL,
    local_dir_path TEXT NOT NULL,
    sha256_verified INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 0,
    installed_at_utc TEXT NOT NULL
);

-- 9. Transactional Outbox untuk Sinkronisasi Andal
CREATE TABLE sync_outbox (
    outbox_id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,                -- 'SESSION' | 'RESULTS' | 'SKELETON' | 'MED_LOG' | 'ALERT'
    entity_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'PENDING',    -- 'PENDING' | 'IN_FLIGHT' | 'SYNCED' | 'FAILED_RETRYABLE' | 'DEAD_LETTER'
    retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at_utc TEXT NOT NULL,
    last_error_code TEXT,
    created_at_utc TEXT NOT NULL
);

CREATE INDEX idx_sessions_patient_time ON sessions(patient_id, started_at_utc DESC);
CREATE INDEX idx_outbox_pending ON sync_outbox(state, next_retry_at_utc);
```

---

## 3. Estimasi Kuota Storage & Kebijakan Retensi

| Tipe Data | Estimasi Ukuran per Sesi (2 Menit @ 15 Hz) | Kebijakan Penyimpanan |
| :--- | :---: | :--- |
| **Video Temporer (Hanya Mode Post-Session)** | `~15–30 MB` | **Dihapus permanen (`secure delete`)** otomatis segera setelah ekstraksi keypoint LB6 selesai (`<= 5 menit`), dan disapu ulang saat app *cold start*. |
| **Blob Keypoint LB6 (`1.800 × 6 × 3 float32` + `zlib`)** | **`~50–90 KB`** | Disimpan di `skeleton_blobs` untuk replay grafik & re-analisis jika ada update model baru. |
| **Metadata Sesi + 118 Window + Episode** | `~12–18 KB` | Disimpan permanen lokal (hingga user menghapus atau melampaui batas retensi 2 tahun/2000 sesi). |
| **Model Bundle ONNX (`YOLO26n` + `LGBM` + `ST-GCN`/`Bi-Mamba`)** | `~6–10 MB` per versi aktif | Hanya menyimpan **maksimal 2 versi** (`active` + `previous_rollback`); versi lebih tua otomatis dihapus. |

---

## 4. Mesin Sinkronisasi *Transactional Outbox* & Resolusi Konflik

1. **Penulisan Atomik:** Setiap kali sesi tes selesai atau log obat dibuat, aplikasi menulis ke tabel bisnis (`sessions`, `fog_episodes`, `medication_logs`) **dan** menyisipkan entri `sync_outbox` dalam **satu transaksi SQLite ACID**.
2. **Eksekusi Worker (`workmanager` / Connectivity Listener):**
   - Hanya berjalan bila `consent_skeleton_sync == 1` **dan** jaringan tersedia.
   - Mengambil item `PENDING` / `FAILED_RETRYABLE` yang `next_retry_at_utc <= now_utc` secara terurut (`SESSION` → `SKELETON` → `RESULTS`).
   - *Exponential Backoff + Jitter:* `30s -> 2m -> 8m -> 30m -> 2h` (maksimal `10` retry sebelum ditandai `DEAD_LETTER` dan menampilkan status *"Perlu sinkronisasi manual"* tanpa membuang data lokal).
3. **Aturan Resolusi Konflik:**
   - **Sesi Klinis, Episode FoG, Window & Skeleton (`Append-Only Immutable`):** Tidak pernah menimpa; unik diidentifikasi oleh `session_id` + `Idempotency-Key`.
   - **Profil Pasien & Kontak Darurat:** *Last-Write-Wins (LWW)* berbasis `updated_at_utc` UTC.

---

## 5. Manajemen Pembaruan Model OTA (*Over-The-Air*)

1. Aplikasi mengecek `GET /api/v1/models/manifest` maksimal 1× per 24 jam (atau saat user menekan *"Cek Pembaruan Model"*).
2. Unduh file `.onnx` / `.txt` **hanya melalui Wi-Fi** secara default (dengan opsi toggle *"Izinkan unduh via data seluler"* untuk file `< 10 MB`).
3. **Validasi Wajib Sebelum Aktivasi:**
   - Cocokkan hash `SHA-256` seluruh file terunduh dengan field di `ModelManifest`.
   - Jalankan *smoke test* 1 dummy tensor `[1, 9, 30, 6]` pada runtime C++ untuk memastikan model dapat dimuat tanpa crash.
   - Lakukan *atomic swap* flag `is_active = 1` pada `model_bundles`. Jika terjadi crash pada 2 sesi pertama memakai bundle baru, sistem melakukan **auto-rollback** ke bundle sebelumnya.
