# Kontrak Live Skeleton HUD, Proyeksi Kamera & Multi-Modal Cueing

Dokumen referensi untuk implementasi `S-05`, `S-06`, `S-07`, dan `S-08` yang menyatukan prototipe [render_pose_demo_videos.py](../../../../../FP-BIOMEDIC---Parkinson-Mobile-FOG/render_pose_demo_videos.py), [EDGE_ML_SPEC.md](../../../../docs/EDGE_ML_SPEC.md), dan [UI_UX_SPEC.md](../../../../docs/UI_UX_SPEC.md).

---

## 1. Topologi Tulang 17 COCO Keypoints & Sorotan LB6

- **Ambang Gambar Titik/Garis:** `conf >= 0.20` (`CONF_VALID_THRES`).
- **Upper Body Bones (11 pasang — garis tipis `2.0 dp`, warna `#38BDF8`, alpha `0.75`):**
  `(0,1), (0,2), (1,3), (2,4), (5,6), (5,7), (7,9), (6,8), (8,10), (5,11), (6,12)`
- **LB6 Lower Body Bones (5 pasang — garis tebal `4.0 dp`, warna mengikuti state):**
  - `(11, 12)` — Pelvis (`L_Hip – R_Hip`)
  - `(11, 13)`, `(13, 15)` — Tungkai Kiri (`L_Hip -> L_Knee -> L_Ankle`)
  - `(12, 14)`, `(14, 16)` — Tungkai Kanan (`R_Hip -> R_Knee -> R_Ankle`)
- **Titik Sendi LB6 (`{11, 12, 13, 14, 15, 16}`):** Lingkaran luar putih radius `6.5 dp`, lingkaran isi radius `4.5 dp` berwarna state (`#22D399` / `#F59E0B` / `#EF4444`).

---

## 2. Rumus Proyeksi Koordinat `BoxFit.cover`

Diberikan koordinat piksel asli hasil un-letterbox `(x_img, y_img)` pada gambar berukuran `(imgW, imgH)` dan ukuran area kamera di layar `(viewW, viewH)`:

```dart
final double scale = math.max(viewW / imgW, viewH / imgH);
final double drawnW = imgW * scale;
final double drawnH = imgH * scale;
final double dx = (viewW - drawnW) * 0.5;
final double dy = (viewH - drawnH) * 0.5;

double screenX = xImg * scale + dx;
if (isFrontCameraMirrored) {
  screenX = viewW - screenX;
}
final double screenY = yImg * scale + dy;
```

*(Pastikan `(imgW, imgH)` sudah ditukar jika orientasi sensor kamera bernilai `90°` atau `270°` terhadap layar portrait.)*

---

## 3. Kontrak Data Masukan HUD (`LiveFrameResult`)

Layer UI hanya mengonsumsi DTO immutable (dibuat di `application/dtos/`) yang berisi:
- `int sequenceId`, `int timestampMs`
- `List<Keypoint2D> keypoints17` (koordinat gambar ter-unletterbox + `conf`)
- `Rect? mainPersonBox` (untuk kotak subjek utama seperti `render_pose_demo_videos.py`)
- `double lb6AvgConf` (`0.0 .. 1.0`), `double effectiveFps`, `bool isLowQualityWindow`
- `AlertTier alertTier` (`GAIT_NORMAL | EARLY_WARNING | FOG_CONFIRMED | FALL_GUARD`)
- `double calibratedRiskScore` (`0.0 .. 100.0`, di mana `50.0 == thr_val`)
- `int elapsedSec` (`0 .. 120`), `int countdownFallSec` (`10 .. 0`)

---

## 4. Matriks Perilaku Visual, Audio RAS & Haptic per State

| State (`AlertTier`) | Warna LB6 & Badge | Audio RAS & TTS Bahasa Indonesia | Haptic Feedback |
| :--- | :--- | :--- | :--- |
| `GAIT_NORMAL` | `#22D399` + `"NORMAL GAIT"` | Diam (atau metronom latihan jika mode RAS aktif) | Tidak ada |
| `EARLY_WARNING` *(1 window `>= thr`)* | `#F59E0B` + `"PERINGATAN DINI"` | 1 chime lembut; belum nyalakan metronom penuh | 1× getar singkat `60 ms` |
| `FOG_CONFIRMED` *(`min_run >= 2`)* | `#EF4444` + `"KAKI MEMBEKU (FoG)"` | Metronom RAS instan (`< 150 ms`, default `80 BPM`, jitter `< 20 ms`) + TTS: *"Berhenti sejenak... tarik napas... langkahkan kaki ikuti ketukan."* | Getar ritmis `80 ms` sinkron ketukan metronom |
| `FALL_GUARD` *(Freeze `>15s` / hip drop)* | Layar penuh S-08 `#0B1B2B` + countdown `10..0` | Sirine perhatian + TTS: *"Apakah Anda baik-baik saja? Tekan layar jika aman."* | Getar berdenyut `300 ms ON / 200 ms OFF` |

- **Stop Hysteresis:** Ketika `FOG_CONFIRMED` aktif, status kembali ke `GAIT_NORMAL` dan metronom otomatis berhenti setelah **2 window berurutan** bernilai `0` (`p < thr_val`).
- **Low-Quality Guard:** Jika `isLowQualityWindow == true` (`> 30%` keypoint LB6 ber-confidence `< 0.20` dalam 1 window), tampilkan banner amber non-blokir: *"Kaki kurang terlihat — cek pencahayaan/jarak kamera"*.
