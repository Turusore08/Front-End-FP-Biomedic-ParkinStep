# Spesifikasi Edge-ML, DSP Sinyal Biomedis & Paritas Numerik — ParkinStep

> **Status Dokumen:** Kontrak Teknis Wajib (Single Source of Truth Edge-AI)  
> **Tanggal:** 2026-11-20  
> **Referensi Kode Sumber Riset:** `../FP-BIOMEDIC---Parkinson-Mobile-FOG/parkinsonfp-biomed.ipynb`, `MobileFOG_Rhama_Training_4Models_Kaggle.ipynb`, `_yolo_extract_worker.py`, `_loso_worker.py`, `joint_schema.json`  

Dokumen ini mengunci seluruh parameter matematika, topologi sendi, skema tensor, koefisien normalisasi, urutan fitur, dan ambang keputusan agar implementasi **C++17 / ONNX Runtime Mobile** pada aplikasi frontend **100% bebas dari *training-serving skew***.

---

## 1. Inventaris Model Produksi & Pemilihan Skenario Default

Berdasarkan hasil evaluasi 16 run eksperimen (`results_summary.csv`) dan audit 27/35-fold LOSO (`loso_35fold_B_15hz/`), profil produksi resmi MVP ditetapkan pada **Skenario B @ 15 Hz (`B_15hz`)**:

| Peran di Aplikasi | Model | File Sumber Riset | Format Target Mobile | Input Tensor | Scaling Input | Threshold (`thr_val`) | Ukuran & Performa Riset |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **Pose Extractor** | `YOLO26n-Pose` | `output/yolo26n-pose.pt` | `yolo26n-pose.onnx` (FP16/FP32) | `[1, 3, 640, 640]` RGB `[0..1]` | `/ 255.0` (Letterbox) | `det_conf = 0.25` | `7.6 MB` (PT), 17 COCO KP, `99.99%` valid |
| **Classifier Utama (Primary)** | **`LightGBM+FFT`** | `checkpoints/lgbm_B_15hz.txt` | `lgbm_b15hz.onnx` / Native Tree | `float32[1, 126]` | **RAW `X` (UNSCALED!)** | **`0.26`** | `193 KB`, 54 trees, `Test F1_pp=0.6390`, `LOSO F1_pp=0.6843` |
| **Classifier Sekunder A (Ringan DL)** | `Light_ST-GCN` | `checkpoints/stgcn_B_15hz.pt` | `stgcn_b15hz.onnx` | `float32[1, 9, 30, 6]` | **`X_scaled`** | **`0.39`** | `182 KB`, `38.801` params, `Test ROC=0.8053`, `LOSO PR=0.4781` |
| **Classifier Sekunder B (PR-AUC Tertinggi)** | `Pure_Bi-Mamba` | `checkpoints/bimamba_B_15hz.pt` | `bimamba_b15hz.onnx` (Static `T=30`) | `float32[1, 9, 30, 6]` | **`X_scaled`** | **`0.15`** | `843 KB`, `212.289` params, `Test PR-AUC=0.6631`, `Spec=0.9368` |

> **ATURAN KERAS INPUT SCALING:**  
> `LightGBM+FFT` dilatih pada tensor **`X` MENTAH (belum di-StandardScaler)**. Sebaliknya, `Light_ST-GCN`, `Pure_Bi-Mamba`, dan `Hybrid_GCN+BiMamba` dilatih pada tensor **`X_scaled`**. Menukar perlakuan scaling antar model akan merusak hasil prediksi secara total.

---

## 2. Stage 1 — Kontrak Ekstraksi Pose (`YOLO26n-Pose`)

### 2.1 Prapemrosesan Frame Kamera
1. **Sampling Rate Target:** Ambil frame tepat pada interval `1 / 15.0 s` (`~66.67 ms`) dari stream kamera (`CameraX` / `AVFoundation`) melalui subsampling deterministik berbasis timestamp sensor kamera.
2. **Transformasi Warna & Letterbox:**
   - Konversi `YUV_420_888` / `BGRA` ke `RGB` 8-bit secara langsung di buffer C++.
   - Lakukan *letterbox resize* dengan mempertahankan *aspect ratio* ke `640 × 640`, padding warna abu-abu standar Ultralytics `114` (`114 / 255.0`), normalisasi ke `float32` rentang `[0.0, 1.0]`, layout **`NCHW` `[1, 3, 640, 640]`**.
   - Simpan faktor skala `gain` dan padding `(pad_x, pad_y)` untuk memproyeksikan kembali koordinat keypoint `(x, y)` ke ruang piksel asli `(W, H)` sebelum dimasukkan ke Stage 2.

### 2.2 Decoding Output & *Main-Person Selection*
- Karena `YOLO26n-Pose` bersifat **NMS-Free** (*One-to-One matching head*), tidak diperlukan tahap pasca-proses Non-Maximum Suppression tradisional. Saring kandidat deteksi dengan `box_conf >= 0.25` (`DET_CONF`).
- Jika tidak ada kandidat (`len == 0`), tandai frame sebagai `valid = false` dan isi keypoint dengan `0.0`.
- **Main-Person Selection (Identik dengan `_yolo_extract_worker.py`):** Jika terdapat `>= 1` orang dalam frame (misalnya pasien + caregiver pendamping), pilih tepat indeks `idx = argmax(score)` dengan formula:
  $$\text{area}_i = (x_{2,i} - x_{1,i}) \cdot (y_{2,i} - y_{1,i})$$
  $$c_{x,i} = 0.5 \cdot (x_{1,i} + x_{2,i})$$
  $$\text{center\_penalty}_i = 1.0 - 0.3 \cdot \frac{|c_{x,i} - 0.5 \cdot W|}{\max(0.5 \cdot W, 1.0)}$$
  $$\text{score}_i = \text{area}_i \cdot \text{conf}_i \cdot \text{center\_penalty}_i$$

---

## 3. Stage 2 — Topologi LB6 & Kontrak DSP Prapemrosesan

### 3.1 Pemetaan Indeks Sendi (`joint_schema.json`)
Dari 17 COCO keypoints (`0..16`), ambil tepat **6 indeks tungkai bawah (LB6)** dalam urutan berikut:

| Indeks LB6 (`V`) | Indeks COCO Asli | Nama Sendi | Indeks Parent (`bone`) |
| :---: | :---: | :--- | :---: |
| `0` | `11` | `L_Hip` | `None` (`bone_x = 0, bone_y = 0`) |
| `1` | `12` | `R_Hip` | `None` (`bone_x = 0, bone_y = 0`) |
| `2` | `13` | `L_Knee` | `0` (`L_Hip`) |
| `3` | `14` | `R_Knee` | `1` (`R_Hip`) |
| `4` | `15` | `L_Ankle` | `2` (`L_Knee`) |
| `5` | `16` | `R_Ankle` | `3` (`R_Knee`) |

### 3.2 Konstanta DSP Terkunci (`parkinsonfp-biomed.ipynb`)

| Konstanta | Nilai Eksak | Keterangan Implementasi |
| :--- | :---: | :--- |
| `TARGET_FS_HZ` | `15.0` | Frekuensi sampling standar produksi (`B_15hz`) |
| `CONF_VALID_THRES` | `0.20` | Titik dengan `conf < 0.20` dianggap hilang/oklusi dan diinterpolasi |
| `HAMPEL_WINDOW` | `7` | Lebar jendela rolling median (3 kiri + tengah + 3 kanan) |
| `HAMPEL_SIGMA` | `3.0` | Pengali MAD: `thresh = 3.0 * 1.4826 * MAD`; jika `|x - med| > thresh`, ganti `x = med` |
| `BUTTER_CUTOFF_HZ` | `9.0` (orde `4`) | **HANYA dijalankan jika `fs >= 25.0`!** Pada `15 Hz`, tahap Butterworth ini **DILEWATI**. |
| `WINDOW_SEC` | `2.0` | Panjang 1 window = `30` frame @ 15 Hz (`60` frame @ 30 Hz) |
| `STRIDE_SEC` | `1.0` | Pergeseran antar window = `15` frame @ 15 Hz (`30` frame @ 30 Hz, overlap 50%) |
| `MIN_RUN_WINDOWS` | `2` | Debounce minimal 2 window berurutan untuk konfirmasi FoG |

### 3.3 Urutan 9 Kanal Skenario B (`C = 0..8`)
Setiap frame pada tensor `X` berdimensi `(T, 6, 9)` (sebelum ditranspose menjadi `(9, T_win, 6)`) wajib mengikuti urutan kanal eksak berikut:
- `0`: `x` (posisi horizontal ternormalisasi terhadap `pelvis_center_x` dan `scale`)
- `1`: `y` (posisi vertikal ternormalisasi terhadap `pelvis_center_y` dan `scale`)
- `2`: `conf` (confidence keypoint asli dari YOLO26n-Pose, rentang `[0.0, 1.0]`)
- `3`: `dx` (turunan pertama `x` terhadap indeks frame `np.gradient(x, axis=0)`)
- `4`: `dy` (turunan pertama `y` terhadap indeks frame `np.gradient(y, axis=0)`)
- `5`: `ddx` (turunan kedua `np.gradient(dx, axis=0)`)
- `6`: `ddy` (turunan kedua `np.gradient(dy, axis=0)`)
- `7`: `bone_x` (`x[v] - x[parent[v]]`, bernilai `0.0` untuk `L_Hip` dan `R_Hip`)
- `8`: `bone_y` (`y[v] - y[parent[v]]`, bernilai `0.0` untuk `L_Hip` dan `R_Hip`)

### 3.4 Dua Mode Eksekusi DSP (*Batch Exact* vs *Causal Streaming*)

Karena `parkinsonfp-biomed.ipynb` menggunakan operasi non-kausal (`median` seluruh trial dan `center=True` pada Hampel), aplikasi mengimplementasikan **dua mode DSP yang terdokumentasi jelas**:

#### Mode A — *Post-Session Batch Exact* (Dipakai untuk Laporan Klinis 2 Menit)
Menjalankan algoritma **identik 100%** dengan fungsi `interpolate_low_conf`, `hampel_filter_1d`, `normalize_lb6`, dan `build_scenario_a_and_b` di `parkinsonfp-biomed.ipynb`:
1. Interpolasi linear `np.interp` pada `(x, y)` di mana `conf < 0.20` (jika 0 frame valid pada satu sendi, set `(x, y) = 0.0`).
2. Terapkan `hampel_filter_1d(window=7, n_sigma=3.0)` pada setiap koordinat `x, y` untuk `v = 0..5` (`min_periods=1`).
3. Hitung `pelvis_center = median(0.5 * (kps[:, 0, :2] + kps[:, 1, :2]))` sepanjang seluruh sesi.
4. Hitung `leg_l = ||L_Hip - L_Knee|| + ||L_Knee - L_Ankle||`, `leg_r = ||R_Hip - R_Knee|| + ||R_Knee - R_Ankle||`, lalu `scale = max(median(0.5 * (leg_l + leg_r)), 1e-4)`.
5. Normalisasi `xy_norm = (xy - pelvis_center) / scale`, hitung vektor `bones`, lalu hitung `dx, dy, ddx, ddy` dengan formula `np.gradient` (beda tengah untuk titik interior, beda maju/mundur orde-1 di tepi indeks `0` dan `T-1`).

#### Mode B — *Live Causal Streaming* (Dipakai untuk *Real-Time Cueing*)
1. **Fase Kalibrasi Awal (`3–5 detik`, `45–75 frame` @ 15 Hz):** Pasien berdiri diam menghadap/terlihat kamera. Hitung `pelvis_center_ref` dan `scale_ref` menggunakan median dari fase kalibrasi ini. Selama sesi berjalan, `pelvis_center` dapat diperbarui perlahan atau dijaga tetap (*anchor*) jika posisi tripod stabil, sedangkan `scale_ref` **dikunci** dengan guard batas aman `[0.5 * scale_ref, 1.5 * scale_ref]` agar jarak kamera tidak merusak skala.
2. **Buffer Kausal 33 Frame (`30 + 3` lookahead = latensi `200 ms` @ 15 Hz):**
   - Menahan 3 frame lookahead (`t+1, t+2, t+3`) memungkinkan filter Hampel `window=7` bersifat **100% identik** dengan versi batch pada titik `t`, sekaligus memungkinkan turunan beda tengah `(f[t+1] - f[t-1]) / 2` dihitung tepat pada frame ke-`t`.
   - Untuk keypoint dengan `conf < 0.20` pada stream real-time (belum diketahui titik masa depan jika oklusi panjang), gunakan interpolasi linear jika gap tertutup dalam `<= 3 frame`, atau *last-valid-observation hold* dengan penanda kualitas `low_quality_window = true` bila rasio titik `conf < 0.20` dalam 1 window melebihi `30%`.

---

## 4. Stage 3 — Spesifikasi Bit-Exact 126 Fitur `LightGBM+FFT`

Input ke `extract_fft_kinematic_features` adalah 1 window `X_raw` berdimensi **`(1, 9, 30, 6)`** (*unscaled*). Urutan dimensi flattened **`Column_0` s.d. `Column_125`** wajib mengikuti urutan tepat berikut (terverifikasi cocok dengan `max_feature_idx=125` pada `lgbm_B_15hz.txt`):

| Rentang Indeks Fitur | Jumlah Fitur | Definisi Matematis & Urutan Loop Eksak | Catatan Kritis Parity |
| :---: | :---: | :--- | :--- |
| **`0 .. 71`** | **72** | Untuk `c_idx` dalam `[0 (x), 1 (y), 3 (dx), 4 (dy)]`:<br>1. `mean` sepanjang sumbu `T` untuk `v=0..5` (6 nilai)<br>2. `std` sepanjang sumbu `T` untuk `v=0..5` (6 nilai)<br>3. `max(abs(·))` sepanjang sumbu `T` untuk `v=0..5` (6 nilai)<br>*(Total: 4 kanal × 3 statistik × 6 sendi = 72)* | **WAJIB `ddof = 0` (population std)** sesuai default NumPy `arr.std(axis=1)`! Jangan gunakan sample std `ddof=1`. |
| **`72 .. 107`** | **36** | Untuk `c_idx` dalam `[3 (dx), 4 (dy)]`:<br>1. Kurangi mean window: `sig = arr - mean(arr, axis=T)`<br>2. Hitung `psd = |rfft(sig)|^2` (16 bin untuk `T=30`, `df = 0.5 Hz`)<br>3. `e_loco = sum(psd[loco_bins]) + 1e-8`<br>4. `e_freeze = sum(psd[freeze_bins]) + 1e-8`<br>5. Urutan append per kanal: `log1p(e_loco)` (6 sendi), `log1p(e_freeze)` (6 sendi), `log1p(e_freeze / e_loco)` (6 sendi)<br>*(Total: 2 kanal × 3 metrik × 6 sendi = 36)* | **Rentang Bin @ `T=30, fs=15.0 Hz`:**<br>`loco_bins = [1, 2, 3, 4, 5, 6]` (`0.5 .. 3.0 Hz`)<br>`freeze_bins = [7, 8, 9, 10, 11, 12, 13, 14]` (`3.5 .. 7.0 Hz`). Bin `15` (`7.5 Hz`) **TIDAK MASUK** karena `7.5 > 0.49 * 15.0 = 7.35 Hz`! *(Pada `T=60, 30 Hz`: freeze_bins `7..16` = `3.5..8.0 Hz`)* |
| **`108 .. 119`** | **12** | Untuk pasangan sendi `(l_j, r_j)` dalam `[(0,1) Hip, (2,3) Knee, (4,5) Ankle]`:<br>`dist_xy[t] = sqrt((x_L - x_R)^2 + (y_L - y_R)^2)`<br>`asym_v[t] = |dx_L - dx_R| + |dy_L - dy_R|`<br>Urutan append per pasangan (4 nilai): `mean(dist_xy)`, `std(dist_xy)`, `mean(asym_v)`, `std(asym_v)` | `std` tetap menggunakan **`ddof = 0`**. Fitur `118` (`mean(asym_v)` pada Ankle) dan `108` (`mean(dist_xy)` pada Hip) adalah *top split* teratas di Tree 0 `lgbm_B_15hz.txt`. |
| **`120 .. 125`** | **6** | `mean(X_raw[0, 2, :, v])` (rata-rata confidence `c=2` untuk `v=0..5`) | Total keseluruhan = `72 + 36 + 12 + 6 = 126` (`Column_0 .. Column_125`). |

- **Sanitasi Numerik:** Setelah penggabungan 126 elemen menjadi `float32`, terapkan `nan_to_num` (`NaN -> 0.0`, `+Inf -> 0.0`, `-Inf -> 0.0`).
- **Normalisasi FFT C++:** Pastikan library FFT (KissFFT / PocketFFT) **tidak menormalisasi output dengan `1/sqrt(N)` atau `1/N`**, melainkan menghitung *unnormalized DFT* standar seperti `numpy.fft.rfft` sehingga `psd = re^2 + im^2` bernilai eksak sama dengan Python.

---

## 5. Stage 4 — Konstanta Model Deep Learning (`Light_ST-GCN` & `Pure_Bi-Mamba`)

### 5.1 Parameter `StandardScaler` (`from_B_denoised_hampel_accel_15hz/scaler_stats.npz`)
Untuk setiap kanal `c = 0..8`, model PyTorch menerima:
$$X_{\text{scaled}}[c, t, v] = \frac{X_{\text{raw}}[c, t, v] - \mu_c}{\sigma_c}$$

| Kanal (`c`) | Nama | `mean` ($\mu_c$) | `std` ($\sigma_c$, sudah termasuk `+1e-6`) |
| :---: | :--- | :---: | :---: |
| `0` | `x` | `0.05256000` | `0.32510000` |
| `1` | `y` | `0.47850001` | `0.40507001` |
| `2` | `conf` | `0.88466001` | `0.26166001` |
| `3` | `dx` | `-0.00002000` | `0.07987000` |
| `4` | `dy` | `-0.00001000` | `0.01337000` |
| `5` | `ddx` | `-0.00001000` | `0.05731000` |
| `6` | `ddy` | `0.00000000` | `0.00986000` |
| `7` | `bone_x` | `0.00343000` | `0.14646000` |
| `8` | `bone_y` | `0.31830999` | `0.23871999` |

*(Catatan: Saat melakukan inference via `models/manifest`, nilai `scaler_mean` dan `scaler_std` diambil secara dinamis dari metadata manifest bundle aktif agar pembaruan model OTA tidak mengunci konstanta lama di kode.)*

### 5.2 Matriks Graf Spasial `A_LB6` Shape `(3, 6, 6)`
Matriks ketetanggaan yang dibekukan di dalam checkpoint `stgcn_B_15hz.pt` dan `hybrid_B_15hz.pt`:
- **Layer 0 (`Root / Self-link`):** Matriks identitas `I_6`.
- **Layer 1 (`Inward / Centripetal`):** `inward[j, i] = 1` untuk edge `[(2,0), (3,1), (4,2), (5,3), (0,1)]`, dinormalisasi kolom (`sum(axis=0)`).
- **Layer 2 (`Outward / Centrifugal`):** Kebalikan arah (`outward[i, j] = 1`) untuk edge yang sama, dinormalisasi kolom (`0.5` pada kolom 1 karena simpul `R_Hip` terhubung outward ke `L_Hip` dan `R_Knee`).

### 5.3 Panduan Ekspor ONNX Khusus `Pure_Bi-Mamba`
Kelas `SelectiveSSM1D` pada `MobileFOG_Rhama_Training_4Models_Kaggle.ipynb` memakai loop `for t in range(L)` dalam pure-PyTorch. Saat mengekspor ke ONNX untuk mobile:
- **Gunakan ukuran panjang sekuens statis (`T = 30`, batch `B = 1`)** menggunakan `torch.onnx.export(..., dynamo=False)` atau unroll `SelectiveSSM1D` dengan `opset_version >= 17` agar graf ter-unroll bersih menjadi operator standar (`MatMul`, `Exp`, `Sigmoid`, `Mul`, `Add`) tanpa operator `Loop` dinamis yang kerap lambat di NNAPI/CoreML.
- Lakukan pengecekan pasca-ekspor dengan `onnxruntime` Python pada 1.652 sampel `test.npz` sebelum file `.onnx` dirilis ke aplikasi mobile.

---

## 6. Stage 5 — Post-Processing, Kalibrasi Skor UI & Gap Diketahui

### 6.1 Aturan Debounce & Two-Tier Alert
- **Raw Binary Window:** `y_raw[k] = 1` jika `p[k] >= thr_val`, selain itu `0`.
- **Confirmed FoG (`min_run = 2`):**
  - Dalam mode *Post-Session Batch*: hapus semua segmen beruntun bernilai `1` yang panjangnya `< 2` window (identik `apply_min_duration_filter`).
  - Dalam mode *Live Streaming*:
    - `y_raw[k] == 1` dan `y_raw[k-1] == 0` → Status **`EARLY_WARNING`** (siapkan sistem, jangan langsung putar sirine).
    - `y_raw[k] == 1` dan `y_raw[k-1] == 1` → Status **`FOG_CONFIRMED`** (picu RAS Audio + Haptic Cueing).
    - Selama `FOG_CONFIRMED` aktif, baru kembali ke `NORMAL` setelah `2` window berurutan bernilai `0` (*hysteresis*).

### 6.2 Kalibrasi Skor untuk Tampilan UI
Karena `thr_val` model berada di rentang rendah (`0.15` untuk `Pure_Bi-Mamba`, `0.26` untuk `LightGBM+FFT`, `0.39` untuk `Light_ST-GCN`), menampilkan angka `p` mentah sebagai persentase (mis. "Kemungkinan FoG 28%" padahal sudah positif FoG) akan membingungkan pasien/dokter. Gunakan fungsi pemetaan piecewise linear ke **Skor Risiko FoG Terkalibrasi (`0–100%`)** di mana `p == thr_val` dipetakan ke **`50%`**:
- Jika `p < thr_val`: `score_ui = 50.0 * (p / thr_val)` (`0 .. 49%` = Normal)
- Jika `p >= thr_val`: `score_ui = 50.0 + 50.0 * ((p - thr_val) / max(1.0 - thr_val, 1e-6))` (`50 .. 100%` = Zona FoG)

### 6.3 Gap Riset yang Diketahui (Rencana v2)
1. **Anti-Swap Kaki Kiri–Kanan:** Belum ada di `parkinsonfp-biomed.ipynb` (meski dicantumkan di slide presentasi). Jika di v2 ditambahkan logika anti-swap, hal itu wajib melatih ulang classifier karena fitur asimetri bilateral (`108..119`) bergantung pada perilaku dataset saat training.
2. **Penyelesaian 8 Fold LOSO Tersisa:** `loso_35fold_B_15hz` baru menyimpan `fold_01..27`. Melengkapi `fold_28..35` dilakukan di repositori riset ML sebelum merilis *bundle_version* model v2.
