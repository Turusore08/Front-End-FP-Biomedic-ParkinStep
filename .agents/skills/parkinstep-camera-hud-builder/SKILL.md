---
name: parkinstep-camera-hud-builder
description: >-
  Builds the real-time camera framing screen, 60 FPS CustomPainter skeleton overlay
  (17 COCO keypoints with thick LB6 lower-body highlight), 3-5 second standing
  calibration UI, Two-Tier RAS cueing controllers, and 10-second Fall Guard screen
  for ParkinStep (screens S-05 through S-08). Use when implementing or debugging
  camera overlays, coordinate projection, or multi-modal FoG alert UI.
---

# ParkinStep Camera HUD & Live Cueing Builder

Skill ini memandu implementasi layar **S-05 (Camera Framing & Kalibrasi)**, **S-06 (Sesi Aktif + Live Skeleton HUD)**, **S-07 (Metronom RAS)**, dan **S-08 (Fall Guard)** agar berjalan mulus di `60 FPS` UI di atas stream inferensi `15 FPS` C++.

---

## Langkah 1 — Muat Kontrak Koordinat, Tulang & Cueing

Baca [hud_and_cueing_contract.md](./references/hud_and_cueing_contract.md) dan pastikan selaras dengan konstanta di [EDGE_ML_SPEC.md](../../../docs/EDGE_ML_SPEC.md) serta FSM di [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md).

## Langkah 2 — Implementasikan Proyeksi Koordinat Kamera ke Layar

1. Buat pure mapper `CameraCoordinateMapper` (terpisah dari widget `CustomPainter`) untuk memproyeksikan `(x_px, y_px)` ruang sensor kamera `(imageW, imageH)` ke ukuran widget `(canvasW, canvasH)`:
   - Tangani `BoxFit.cover` (skala `max(canvasW/imageW, canvasH/imageH)` + offset crop terpusat).
   - Tangani rotasi sensor Android (`90°` / `270°`) dan flip horizontal otomatis bila kamera depan aktif.
2. **Dilarang** melakukan logika DSP (`Hampel`, `FFT`, `normalize_lb6`) di dalam layer `presentation/`; widget hanya menerima DTO `LiveFrameResult` yang sudah matang dari `ClinicalSessionFsm`.

## Langkah 3 — Bangun `SkeletonHudPainter` (60 FPS, Zero Jank)

1. Bungkus widget overlay di dalam **`RepaintBoundary`** agar kamera preview dan header HUD tidak ikut ter-repaint setiap frame.
2. Implementasikan `shouldRepaint` dengan membandingkan timestamp/sequence frame terbaru saja.
3. Gambar topologi sesuai [hud_and_cueing_contract.md](./references/hud_and_cueing_contract.md):
   - Upper body (`0..10`): garis tipis `2.0 dp` `#38BDF8` (opacity `0.75`).
   - **LB6 (`[11..16]`: Hip–Knee–Ankle):** garis tebal **`4.0 dp`**, titik sendi radius `6.5 dp` dengan border putih `2.0 dp`, berubah warna dinamis sesuai `AlertTier` (`#22D399` Normal, `#F59E0B` Early Warning, `#EF4444` Confirmed FoG).
   - Abaikan segmen yang salah satu ujungnya memiliki `conf < 0.20` (`CONF_VALID_THRES`).

## Langkah 4 — Bangun S-05 Framing & Kalibrasi 3–5 Detik

1. Render kotak siluet tubuh tengah untuk memandu caregiver menempatkan pasien tepat di zona pusat (mendukung rumus `_select_main_person` agar pendamping di tepi frame tidak terpilih).
2. Tampilkan 2 badge status kualitas (*LB6 Conf* `< 0.20` / `0.20–0.50` / `>= 0.50` dan *Pencahayaan/Jarak*).
3. Kunci fase kalibrasi `3–5 detik` (`45–75 frame` @ 15 Hz) menggunakan animasi cincin `#1AEAD8` + TTS Bahasa Indonesia sebelum masuk rekaman aktif 120 detik.

## Langkah 5 — Hubungkan Two-Tier Cueing (S-06/S-07) & Fall Guard (S-08)

1. Hubungkan `AlertTier` ke `CueingPort` (Audio RAS `< 20 ms` jitter via `flutter_soloud`, TTS Bahasa Indonesia, Haptic) dan visual (`ParkinRiskGauge`, `ParkinHighlightPrompt`, `ParkinProgressPill`).
2. Pastikan layar `S-08` (`FALL_GUARD`) mengambil alih fokus penuh dengan tombol pembatalan `>= 84 dp` ("SAYA BAIK-BAIK SAJA") dan hitung mundur `10..0` detik.
3. Kelola `WakeLock.enable()` saat masuk `S-05` dan `WakeLock.disable()` pada `dispose`/`onPause`.

## Langkah 6 — Verifikasi

Jalankan widget test proyeksi koordinat + auditor aksesibilitas:

```bash
python3 .agents/skills/parkinstep-a11y-auditor/scripts/audit_flutter_ui.py lib/presentation && flutter test
```
