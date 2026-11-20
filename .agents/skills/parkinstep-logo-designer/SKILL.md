---
name: parkinstep-logo-designer
description: >-
  Designs, generates, validates, and packages brand logos, wordmarks, and mobile app
  launcher icons specifically for the ParkinStep (Mobile-FOG) Parkinson's gait screening
  application. Use this skill whenever the user asks to design, explore concepts for,
  generate, refine, vectorize, or export the ParkinStep logo, splash mark, clinical PDF
  header mark, or Android/iOS launcher icon aligned with the Beats Medical visual reference
  in contoh/.
---

# ParkinStep Logo & Brand Mark Designer

Skill ini memandu pembuatan identitas visual **ParkinStep (Mobile-FOG)** agar harmonis dengan referensi UI **Beats Medical** di folder `contoh/` namun memiliki makna klinis dan karakter visual yang unik, hangat, modern, dan ramah pasien Parkinson.

> **Aturan Keras Workspace:** Jangan mengubah atau mengisi `docs/UI_UX_SPEC.md` secara otomatis saat menjalankan skill ini kecuali pengguna memintanya secara eksplisit.

---

## Langkah 1 — Pahami DNA Visual & Diferensiasi Brand

Sebelum membuat konsep atau prompt apa pun, baca [brand_visual_dna.md](./references/brand_visual_dna.md) untuk mengunci:
1. **Palet Warna Resmi** hasil ekstraksi referensi `contoh/` (`#0B1B2B` Midnight Navy, `#234085` Royal Navy, `#00A9EC` Vibrant Azure, `#1AEAD8` Rhythm Aqua, `#D8F1FC` Soft Ice, `#FFFFFF`).
2. **Makna Biomekanika ParkinStep:** Deteksi *Freezing of Gait* berbasis kamera (6 sendi tungkai bawah **LB6**: Pinggul–Lutut–Engkel + protokol putar **360°**) yang membebaskan langkah kaki pasien lewat irama **RAS** (*Rhythmic Auditory Stimulation*).
3. **Anti-Pattern Wajib:** Jangan meniru huruf `BM` atau bar equalizer polos milik Beats Medical; jangan memakai simbol tengkorak/tulang menyeramkan, warna merah dominan, *hairline stroke* tipis, atau teks kecil di dalam *app icon*.

---

## Langkah 2 — Pilih / Eksplorasi 3 Arah Konsep

Tawarkan atau eksplorasi konsep dari 3 arah berikut (baca detailnya di [prompt_templates.md](./references/prompt_templates.md)):

| Kode Konsep | Metafora Visual Utama | Kekuatan Klinis & Estetik |
| :--- | :--- | :--- |
| **Konsep A (Direkomendasikan)** | **Kinetic Stride `"P"` + Cadence Wave** | Monogram `"P"` geometris membulat yang kakinya berubah menjadi lengkung langkah dinamis + gelombang irama aqua (`#1AEAD8`). Paling kuat dibaca pada ukuran icon kecil (`24–48 px`). |
| **Konsep B** | **LB6 Gait Constellation** | Abstraksi hangat 3–4 node sendi (*Hip → Knee → Ankle*) membentuk postur langkah maju (terinspirasi langsung dari *6-joint LB6 pose pipeline* YOLO26n-Pose) dengan aura gerak melengkung. |
| **Konsep C** | **360° Motion Ring + Stepping Foot** | Cincin putar 360° terbuka (merujuk protokol *Turning-in-Place*) bergradien Azure-to-Aqua yang mengarah ke gerak telapak melangkah keluar dari zona beku (*unfreezing*). |

---

## Langkah 3 — Produksi Aset (Jalur Ganda: Eksplorasi AI & Master Vektor)

### Jalur 3A — Eksplorasi Konsep Cepat dengan `image-generator`
1. Pilih template prompt dari [prompt_templates.md](./references/prompt_templates.md) sesuai konsep (`A`, `B`, atau `C`).
2. Panggil subagent `image-generator` untuk menghasilkan **2–3 kandidat konsep** pada latar `#0B1B2B` atau `#FFFFFF` berasio `1:1` (`1024×1024`).
3. Presentasikan kandidat terbaik kepada pengguna untuk dipilih/disetujui sebelum vektorisasi final.

### Jalur 3B — Pembuatan Master Vektor SVG Bersih (Wajib untuk Produksi Mobile)
1. Gunakan kanvas dasar [svg_grid_template.svg](./resources/svg_grid_template.svg) (`viewBox="0 0 1024 1024"`).
2. Pastikan seluruh geometri logo utama berada di dalam **Android Adaptive Safe Zone** (`r <= 338 px` dari pusat `512, 512`, yakni 66% diameter) dan patuh margin optik minimal 10%.
3. Jangan gunakan tag `<text>` mentah pada file *app icon* (konversi seluruh bentuk ke `<path>`, `<circle>`, atau `<rect>` berujung bulat `stroke-linecap="round"`).
4. Untuk tipe lockup horizontal (header aplikasi / laporan PDF), sediakan jarak *clear space* minimal `0.5 × tinggi icon` antara logo mark dan wordmark **`ParkinStep`** (opsi penekanan dua warna seperti `"Good Morning, Dave"` di `contoh/`: `Parkin` dalam Navy/White + `Step` dalam Vibrant Azure `#00A9EC`).

---

## Langkah 4 — Hasilkan 4 Varian Deliverable Wajib

Agar kompatibel dengan seluruh permukaan UI referensi `contoh/` serta kebutuhan klinis di `docs/PRD.md`, hasilkan **4 varian file**:

| Nama File Output (di `assets/branding/`) | Penggunaan Spesifik | Spesifikasi Warna & Latar |
| :--- | :--- | :--- |
| `parkinstep_icon_master.svg` | Launcher App Icon Android/iOS, Splash Screen | Simbol murni tanpa teks; latar gradien/solid `#0B1B2B` atau `#00A9EC` |
| `parkinstep_lockup_light.svg` | Header Home screen terang (setara `BM \|\|\|\|\|` di `contoh/`) | Logo mark Azure/Aqua + wordmark `#234085` / `#0077B6` (AA `4.87:1`) untuk latar `#FFFFFF` |
| `parkinstep_lockup_dark.svg` | Layar Login/Auth gelap (setara `BEATS MEDICAL \|\|\|\|\|` di `contoh/`) | Logo mark Azure/Aqua + wordmark `#FFFFFF` / `#00A9EC` (AA `6.54:1`) untuk latar `#0B1B2B` |
| `parkinstep_mono_clinical.svg` | Header laporan PDF klinis dokter saraf & watermark cetak | Monokrom solid `#234085` (Clinical Royal Navy), terbaca jelas saat dicetak hitam-putih |

---

## Langkah 5 — Validasi Otomatis Sebelum Pengiriman

Jalankan skrip validator bawaan terhadap seluruh file logo yang dihasilkan dan audit kontras paletnya:

```bash
python3 .agents/skills/parkinstep-logo-designer/scripts/verify_logo_assets.py assets/branding/*.svg --check-palette
```

Pastikan seluruh pemeriksaan **LULUS (`exit code 0`)**:
- XML SVG valid, `viewBox` simetris/proporsional, bebas `<script>` atau `data:image/` (pure vector).
- File `*icon*` tidak mengandung elemen `<text>` mentah.
- Rasio kontras WCAG 2.1 memenuhi standar keterbacaan pasien lansia.
- Uji keterbacaan visual dengan merender preview pada ukuran kecil (`24×24 px` dan `48×48 px`) agar detail logo tidak pecah atau saling menempel.

---

## Langkah 6 — Pengemasan & Serah Terima ke User

1. Simpan aset terverifikasi ke folder `assets/branding/` (buat direktori jika belum ada).
2. Jika diperlukan raster PNG untuk launcher Android (`mipmap-*`) / iOS (`AppIcon.appiconset`), ekspor dari SVG master ke `1024×1024` (iOS/Play Store), `512×512`, dan `432×432` (Android Adaptive Foreground).
3. Laporkan ringkasan konsep, filosofi warna/bentuk, hasil output `verify_logo_assets.py`, serta tautkan seluruh file hasil agar pengguna dapat meninjau atau meminta iterasi.
