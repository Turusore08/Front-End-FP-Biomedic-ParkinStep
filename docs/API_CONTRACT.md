# Kontrak API Backend, WebSocket & BLE (Opsional Fase 2) — ParkinStep

> **Status Dokumen:** Kontrak Integrasi Resmi (v1.0.0)  
> **Standar:** OpenAPI 3.1.0 (REST HTTPS) + WebSocket Secure (`WSS`)  
> **Tanggal:** 2026-11-20  
> **Catatan Status Backend:** Repositori ML (`FP-BIOMEDIC---Parkinson-Mobile-FOG`) saat ini belum memiliki server API. Kontrak di bawah menjadi *Single Source of Truth* untuk pengembangan klien frontend (Dart/Freezed) dan backend pendamping (FastAPI/Pydantic V2).

---

## 1. Konvensi Kontrak & Guardrails Anti-Drift

Seluruh skema REST dan WebSocket wajib mematuhi aturan sinkronisasi kontrak (*API Contract Sync*):

1. **Nullable vs Optional Eksplisit:**
   - Field opsional (key boleh absen) berbeda dari field nullable (`type: ["string", "null"]`). Di klien Dart/TypeScript, gunakan pembedaan tegas antara default absen dan nilai `null` eksplisit.
2. **Standar Timestamp:**
   - **WAJIB** menggunakan string **ISO-8601 UTC** berakhiran `Z` (contoh: `2026-11-20T08:45:12Z`). Dilarang mengirim timestamp lokal tanpa offset zona waktu.
3. **String Enums (`StrEnum`):**
   - Seluruh enum wajib dikirim sebagai string literal huruf kapital (`"PATIENT"`, `"ON"`, `"TURNING_360_2MIN"`), **bukan** angka integer.
4. **Idempotency pada Operasi Mutasi (*Offline-First Retry Safety*):**
   - Semua endpoint `POST` pembuatan sesi, log obat, unggah hasil, dan alert darurat wajib menyertakan header `Idempotency-Key: <UUIDv7>` dan ID entitas yang dibuat di klien (`session_id` / `log_id`) agar retry jaringan di pedesaan tidak menggandakan record.
5. **Format Error Terstandar (RFC 7807 `application/problem+json`):**
   - Error HTTP `4xx/5xx` wajib mengembalikan `type`, `title`, `status`, `detail`, `instance`, dan `error_code` stabil.

---

## 2. Daftar Ringkas Endpoint REST API

| Kategori | Method & Path | Fungsi | Idempotency / Auth |
| :--- | :--- | :--- | :--- |
| **Auth** | `POST /api/v1/auth/login` | Login user (`PATIENT \| CAREGIVER \| CLINICIAN`) | Public / Rate-limited |
| **Auth** | `POST /api/v1/auth/refresh` | Rotasi Refresh Token → Access JWT baru | Refresh Token |
| **Auth** | `POST /api/v1/auth/logout` | Revoke refresh token sesi perangkat | Bearer JWT |
| **Pasien** | `GET /api/v1/patients/{patient_id}` | Ambil profil pasien, kontak darurat, consent flags | Bearer JWT |
| **Pasien** | `PATCH /api/v1/patients/{patient_id}` | Update kontak darurat atau pencabutan consent UU PDP | Bearer JWT |
| **Pasien** | `DELETE /api/v1/patients/{patient_id}` | Hak penghapusan permanen data cloud (*UU PDP*) | Bearer JWT + Re-auth |
| **Medikasi** | `POST /api/v1/patients/{patient_id}/medications` | Catat konsumsi obat & status Levodopa | Bearer JWT + `Idempotency-Key` |
| **Medikasi** | `GET /api/v1/patients/{patient_id}/medications` | Daftar riwayat minum obat (paginated) | Bearer JWT |
| **Sesi Tes** | `POST /api/v1/sessions` | Registrasi metadata sesi baru | Bearer JWT + `Idempotency-Key` |
| **Sesi Tes** | `POST /api/v1/sessions/{session_id}/skeleton-frames` | Unggah batch keypoint LB6 `T×6×3` (*privacy-preserving*) | Bearer JWT + `Idempotency-Key` |
| **Sesi Tes** | `POST /api/v1/sessions/{session_id}/results` | Unggah hasil inferensi, timeline window, & episode FoG | Bearer JWT + `Idempotency-Key` |
| **Sesi Tes** | `POST /api/v1/sessions/{session_id}/analyze-video` | *(Cloud Fallback Opt-In)* Analisis video terenkripsi | Bearer JWT + Consent B |
| **Laporan** | `GET /api/v1/sessions/{session_id}/report` | Unduh laporan klinis (`?format=json\|pdf`) | Bearer JWT |
| **Analitik** | `GET /api/v1/patients/{patient_id}/analytics/trends` | Tren longitudinal `FoG%` & perbandingan `ON` vs `OFF` | Bearer JWT |
| **Model OTA** | `GET /api/v1/models/manifest` | Cek versi bundle model ONNX, hash SHA-256, `scaler`, `thr_val` | Bearer JWT / App Key |
| **Darurat** | `POST /api/v1/alerts/emergency` | Kirim peringatan jatuh / freeze `> 15s` ke caregiver | Bearer JWT + `Idempotency-Key` |

---

## 3. Spesifikasi OpenAPI 3.1.0 (Inti Kontrak Klien & Server)

```yaml
openapi: 3.1.0
info:
  title: ParkinStep (Mobile-FOG) Companion API
  version: 1.0.0
  description: >
    API sinkronisasi telemedicine, registry model edge OTA, log medikasi Levodopa,
    dan notifikasi darurat untuk aplikasi mobile ParkinStep.
servers:
  - url: https://api.parkinstep.example.org/api/v1
    description: Production HTTPS Endpoint

security:
  - BearerAuth: []

paths:
  /auth/login:
    post:
      security: []
      summary: Autentikasi akun pasien, caregiver, atau klinisi
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [identifier, password, device_id]
              properties:
                identifier: { type: string }
                password: { type: string, format: password }
                device_id: { type: string }
      responses:
        "200":
          description: Berhasil login
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/AuthTokenResponse"

  /patients/{patient_id}/medications:
    post:
      summary: Catat jadwal atau konsumsi medikasi Levodopa
      parameters:
        - $ref: "#/components/parameters/PatientId"
        - $ref: "#/components/parameters/IdempotencyKey"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/MedicationLogCreate"
      responses:
        "201":
          description: Log medikasi tersimpan
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/MedicationLogResponse"

  /sessions:
    post:
      summary: Registrasi sesi tes 360° Turning-in-Place (offline-first compatible)
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/SessionCreateRequest"
      responses:
        "201":
          description: Sesi terdaftar
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/SessionSummary"

  /sessions/{session_id}/skeleton-frames:
    post:
      summary: Unggah batch keypoint LB6 anonim (tanpa video mentah)
      parameters:
        - $ref: "#/components/parameters/SessionId"
        - $ref: "#/components/parameters/IdempotencyKey"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/SkeletonBatchUpload"
      responses:
        "202":
          description: Batch skeleton diterima

  /sessions/{session_id}/results:
    post:
      summary: Unggah ringkasan episode FoG & probabilitas window hasil Edge-AI
      parameters:
        - $ref: "#/components/parameters/SessionId"
        - $ref: "#/components/parameters/IdempotencyKey"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/SessionResultUpload"
      responses:
        "200":
          description: Hasil sesi tersinkronisasi

  /patients/{patient_id}/analytics/trends:
    get:
      summary: Ambil tren perkembangan FoG & komparasi ON vs OFF medikasi
      parameters:
        - $ref: "#/components/parameters/PatientId"
        - name: from_utc
          in: query
          required: false
          schema: { type: string, format: date-time }
        - name: to_utc
          in: query
          required: false
          schema: { type: string, format: date-time }
      responses:
        "200":
          description: Data tren longitudinal
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/PatientTrendsResponse"

  /models/manifest:
    get:
      summary: Ambil manifest versi model Edge-AI OTA, scaler_stats & threshold resmi
      responses:
        "200":
          description: Manifest bundle model aktif
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ModelManifest"

  /alerts/emergency:
    post:
      summary: Kirim eskalasi darurat jatuh atau prolonged freeze > 15 detik
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/EmergencyAlertRequest"
      responses:
        "202":
          description: Notifikasi darurat dikirim ke kontak caregiver

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  parameters:
    PatientId:
      name: patient_id
      in: path
      required: true
      schema: { type: string, format: uuid }
    SessionId:
      name: session_id
      in: path
      required: true
      schema: { type: string, format: uuid }
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: true
      schema: { type: string, format: uuid }

  schemas:
    UserRole:
      type: string
      enum: [PATIENT, CAREGIVER, CLINICIAN]
    MedicationState:
      type: string
      enum: [ON, OFF, UNKNOWN]
    InferenceMode:
      type: string
      enum: [LIVE_CAUSAL, POST_SESSION_EXACT, CLOUD_FALLBACK]
    SessionProtocol:
      type: string
      enum: [TURNING_360_2MIN, WALK_BACK_AND_FORTH_2MIN, SIT_TO_STAND_2MIN, FREE_WALK_MONITORING]
    ClassifierName:
      type: string
      enum: [LIGHTGBM_FFT, LIGHT_STGCN, PURE_BIMAMBA]
    EmergencyTrigger:
      type: string
      enum: [PROLONGED_FREEZE_15S, SUDDEN_HIP_DROP_IMMOBILITY]

    AuthTokenResponse:
      type: object
      required: [access_token, refresh_token, expires_in_sec, user_id, role]
      properties:
        access_token: { type: string }
        refresh_token: { type: string }
        expires_in_sec: { type: integer }
        user_id: { type: string, format: uuid }
        role: { $ref: "#/components/schemas/UserRole" }

    MedicationLogCreate:
      type: object
      required: [log_id, drug_name, dosage_mg, taken_at_utc, med_state]
      properties:
        log_id: { type: string, format: uuid }
        drug_name: { type: string, maxLength: 120 }
        dosage_mg: { type: number, minimum: 0 }
        taken_at_utc: { type: string, format: date-time }
        med_state: { $ref: "#/components/schemas/MedicationState" }
        notes: { type: [string, "null"] }

    MedicationLogResponse:
      allOf:
        - $ref: "#/components/schemas/MedicationLogCreate"
        - type: object
          required: [patient_id, synced_at_utc]
          properties:
            patient_id: { type: string, format: uuid }
            synced_at_utc: { type: string, format: date-time }

    SessionCreateRequest:
      type: object
      required:
        - session_id
        - patient_id
        - protocol
        - inference_mode
        - med_state
        - target_fps
        - model_bundle_version
        - started_at_utc
        - safety_checklist_confirmed
      properties:
        session_id: { type: string, format: uuid }
        patient_id: { type: string, format: uuid }
        protocol: { $ref: "#/components/schemas/SessionProtocol" }
        inference_mode: { $ref: "#/components/schemas/InferenceMode" }
        med_state: { $ref: "#/components/schemas/MedicationState" }
        last_medication_log_id: { type: [string, "null"], format: uuid }
        target_fps: { type: integer, enum: [15, 30] }
        model_bundle_version: { type: string }
        started_at_utc: { type: string, format: date-time }
        safety_checklist_confirmed: { type: boolean }

    SessionSummary:
      allOf:
        - $ref: "#/components/schemas/SessionCreateRequest"
        - type: object
          required: [created_at_utc]
          properties:
            created_at_utc: { type: string, format: date-time }

    SkeletonBatchUpload:
      type: object
      required: [chunk_index, sampling_hz, frame_timestamps_ms, lb6_xyc]
      properties:
        chunk_index: { type: integer, minimum: 0 }
        sampling_hz: { type: number, enum: [15.0, 30.0] }
        frame_timestamps_ms:
          type: array
          items: { type: integer }
        lb6_xyc:
          description: "Array [T][6][3] dengan urutan L_Hip, R_Hip, L_Knee, R_Knee, L_Ankle, R_Ankle"
          type: array
          items:
            type: array
            minItems: 6
            maxItems: 6
            items:
              type: array
              minItems: 3
              maxItems: 3
              items: { type: number }

    FogEpisodeItem:
      type: object
      required: [episode_index, start_sec, end_sec, duration_sec, peak_calibrated_score]
      properties:
        episode_index: { type: integer, minimum: 1 }
        start_sec: { type: number, minimum: 0 }
        end_sec: { type: number, minimum: 0 }
        duration_sec: { type: number, minimum: 0 }
        peak_calibrated_score: { type: number, minimum: 0, maximum: 100 }
        mean_freeze_index: { type: [number, "null"] }

    WindowPredictionItem:
      type: object
      required: [window_idx, start_sec, end_sec, raw_prob, calibrated_score, pred_raw, pred_postprocessed, low_quality_flag]
      properties:
        window_idx: { type: integer, minimum: 0 }
        start_sec: { type: number }
        end_sec: { type: number }
        raw_prob: { type: number, minimum: 0, maximum: 1 }
        calibrated_score: { type: number, minimum: 0, maximum: 100 }
        pred_raw: { type: integer, enum: [0, 1] }
        pred_postprocessed: { type: integer, enum: [0, 1] }
        freeze_index_ankle: { type: [number, "null"] }
        bilateral_asym_ankle: { type: [number, "null"] }
        low_quality_flag: { type: boolean }

    SessionResultUpload:
      type: object
      required:
        - classifier_used
        - threshold_used
        - ended_at_utc
        - duration_sec
        - valid_lb6_ratio
        - fog_percentage
        - episode_count
        - total_fog_duration_sec
        - median_episode_duration_sec
        - episodes
        - windows
      properties:
        classifier_used: { $ref: "#/components/schemas/ClassifierName" }
        threshold_used: { type: number }
        ended_at_utc: { type: string, format: date-time }
        duration_sec: { type: number }
        valid_lb6_ratio: { type: number, minimum: 0, maximum: 1 }
        fog_percentage: { type: number, minimum: 0, maximum: 100 }
        episode_count: { type: integer, minimum: 0 }
        total_fog_duration_sec: { type: number, minimum: 0 }
        median_episode_duration_sec: { type: number, minimum: 0 }
        episodes:
          type: array
          items: { $ref: "#/components/schemas/FogEpisodeItem" }
        windows:
          type: array
          items: { $ref: "#/components/schemas/WindowPredictionItem" }

    PatientTrendsResponse:
      type: object
      required: [patient_id, total_sessions, on_med_avg_fog_pct, off_med_avg_fog_pct, points]
      properties:
        patient_id: { type: string, format: uuid }
        total_sessions: { type: integer }
        on_med_avg_fog_pct: { type: [number, "null"] }
        off_med_avg_fog_pct: { type: [number, "null"] }
        points:
          type: array
          items:
            type: object
            required: [session_id, started_at_utc, med_state, fog_percentage, episode_count]
            properties:
              session_id: { type: string, format: uuid }
              started_at_utc: { type: string, format: date-time }
              med_state: { $ref: "#/components/schemas/MedicationState" }
              fog_percentage: { type: number }
              episode_count: { type: integer }

    ModelArtifactSpec:
      type: object
      required: [name, format, download_url, sha256, size_bytes]
      properties:
        name: { type: string }
        format: { type: string, enum: [ONNX, LGBM_TXT] }
        download_url: { type: string, format: uri }
        sha256: { type: string, pattern: "^[a-f0-9]{64}$" }
        size_bytes: { type: integer }
        requires_scaled_input: { type: [boolean, "null"] }
        threshold_val: { type: [number, "null"] }

    ModelManifest:
      type: object
      required: [bundle_version, target_fps, window_sec, stride_sec, min_run_windows, pose_estimator, primary_classifier, scaler_mean_b15hz, scaler_std_b15hz]
      properties:
        bundle_version: { type: string }
        target_fps: { type: integer, enum: [15] }
        window_sec: { type: number }
        stride_sec: { type: number }
        min_run_windows: { type: integer }
        pose_estimator: { $ref: "#/components/schemas/ModelArtifactSpec" }
        primary_classifier: { $ref: "#/components/schemas/ModelArtifactSpec" }
        secondary_classifier:
          oneOf:
            - $ref: "#/components/schemas/ModelArtifactSpec"
            - type: "null"
        scaler_mean_b15hz:
          type: array
          minItems: 9
          maxItems: 9
          items: { type: number }
        scaler_std_b15hz:
          type: array
          minItems: 9
          maxItems: 9
          items: { type: number }

    EmergencyAlertRequest:
      type: object
      required: [alert_id, patient_id, session_id, trigger_type, triggered_at_utc, cancelled_by_user]
      properties:
        alert_id: { type: string, format: uuid }
        patient_id: { type: string, format: uuid }
        session_id: { type: string, format: uuid }
        trigger_type: { $ref: "#/components/schemas/EmergencyTrigger" }
        triggered_at_utc: { type: string, format: date-time }
        cancelled_by_user: { type: boolean }
```

---

## 4. Kontrak WebSocket (*Cloud Keypoint Streaming Fallback — Opsional*)

Digunakan **hanya** apabila perangkat tidak mampu menjalankan classifier deep learning tertentu atau pengguna memilih `inference_mode = CLOUD_FALLBACK`. Video mentah tetap **tidak** di-stream; hanya koordinat LB6 15 Hz (`~1.1 KB/s`).

- **Endpoint:** `wss://api.parkinstep.example.org/ws/v1/stream/keypoints/{session_id}` (Header: `Authorization: Bearer <JWT>`)
- **Frame Client → Server (15 Hz):**
```json
{
  "type": "LB6_FRAME",
  "seq": 45,
  "t_ms": 3000,
  "lb6_xyc": [
    [512.4, 340.1, 0.94],
    [568.2, 341.0, 0.92],
    [515.0, 445.8, 0.89],
    [570.1, 447.2, 0.90],
    [518.3, 558.4, 0.86],
    [572.6, 560.1, 0.88]
  ]
}
```
- **Prediksi Server → Client (tiap stride `1.0 s` sejak `t >= 2.0 s`):**
```json
{
  "type": "WINDOW_PREDICTION",
  "window_idx": 1,
  "raw_prob": 0.3412,
  "calibrated_score": 55.4,
  "alert_tier": "FOG_CONFIRMED",
  "freeze_index_ankle": 2.41
}
```

---

## 5. Kontrak BLE GATT (*Fase 2 Opsional — Riset Validasi IMU 128 Hz*)

Disiapkan untuk kompatibilitas jika di Fase 2 aplikasi dihubungkan ke modul IMU tulang kering guna validasi klinis (*Scenario F oracle baseline*):
- **Target Frekuensi:** `128 Hz` (`dt = 7.8125 ms`), format sensor **6-aksis** mengikuti kolom dataset `SUBxx_y.txt`:
  `ACC ML [g]`, `ACC AP [g]`, `ACC SI [g]`, `GYR ML [deg/s]`, `GYR AP [deg/s]`, `GYR SI [deg/s]`.
- **Struktur Payload Characteristic Notify (28 bytes packed little-endian per sampel / batched per 4 sampel = 112 bytes untuk menghindari keterbatasan MTU BLE):**
  - `uint32 timestamp_us` (4 bytes)
  - `float32[3] acc_ml_ap_si` (12 bytes, satuan `g`)
  - `float32[3] gyr_ml_ap_si` (12 bytes, satuan `deg/s`)

---

## 6. Alur Sinkronisasi Kode Kontrak CI

1. Perubahan skema pada backend atau `docs/API_CONTRACT.md` wajib diperiksa dengan **`oasdiff diff --breaking`** agar tidak merusak versi aplikasi yang sudah terpasang di ponsel pasien.
2. Klien Dart menghasilkan DTO `freezed` dan Retrofit/Dio interface langsung dari skema OpenAPI ini untuk menjamin *zero schema drift*.
