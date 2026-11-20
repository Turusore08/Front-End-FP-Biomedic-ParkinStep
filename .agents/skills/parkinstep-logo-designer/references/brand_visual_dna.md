# Brand & Visual DNA — ParkinStep (Berbasis Referensi `contoh/` Beats Medical)

Dokumen ini merupakan hasil audit visual 5 tangkapan layar aplikasi **Beats Medical** di folder `contoh/` yang dipadukan dengan domain klinis **ParkinStep (Mobile-FOG)**.

---

## 1. Palet Warna Resmi (*Pixel-Verified* dari `contoh/`)

Dari hasil sampling piksel pada layar Login gelap (`16.10.35.jpeg`), layar Metronome/Timer (`16.10.40.jpeg`), dan layar Home (`16.10.42.jpeg`), ditemukan palet *Medical Ocean & Aqua* yang konsisten dan menenangkan:

| Token Warna | HEX Resmi | Sampled `contoh/` | Peran di UI & Logo ParkinStep |
| :--- | :---: | :---: | :--- |
| **Deep Midnight Navy** | `#0B1B2B` | `#081828` (74.9% layar login) | Latar *Dark Mode*, kanvas splash screen, dan latar *Dark App Icon* |
| **Clinical Royal Navy** | `#234085` | `#284888` (9.7% layar home) | Wordmark mode terang, header navigasi, ikon klinis, dan versi monokrom PDF |
| **Primary Vibrant Azure** | `#00A9EC` | `#08A8E8` (15.6% layar timer) | Warna inti logo mark, CTA utama (*Login / Start*), dan aksen nama `"Step"` |
| **Rhythm Aqua / Electric Mint** | `#1AEAD8` | `#18F8E8` (4.1% cincin pulse) | Aksen gerak/ritme RAS, gradasi dinamis pada logo mark, dan highlight *progress/pulse* |
| **Soft Ice Surface** | `#D8F1FC` | `#C8E8F8` / `#E8F8F8` | Badge ikon membulat, permukaan kartu sekunder, & latar *light icon container* |
| **Pure Clinical White** | `#FFFFFF` | `#F8F8F8` (40–55% layar aktif) | Kanvas utama aplikasi terang & teks wordmark di atas latar `#0B1B2B` |

### Warna Semantik Klinis (Khusus Status Sinyal UI, **BUKAN Warna Dominan Logo**)
- **Normal Gait / Aman:** `#22D399` (Emerald Mint — konsisten dengan status `NORMAL GAIT` dan rentang hijau gauge)
- **Early Warning / Perhatian:** `#F59E0B` (Warm Amber — sesuai busur kiri gauge di `16.10.40 (1).jpeg`)
- **FoG Confirmed / Alert:** `#EF4444` (Alert Coral-Red — khusus indikator `FREEZING OF GAIT` & darurat)

---

## 2. Bahasa Bentuk (*Shape Language*) & Karakter Tipografi

Audit 5 screenshot `contoh/` menunjukkan karakter estetika berikut yang harus diterjemahkan ke logo **ParkinStep**:

1. **Geometri Bulat & Terbuka (*Approachable Medical Minimalism*):**
   - Semua tombol, card, badge ikon, dan gauge menggunakan sudut membulat lembut (*rounded pill & squircle*) tanpa sudut tajam agresif.
   - Simbol gerak (*shoe stepping* & *hand writing*) menggunakan garis tegas berujung bulat (`stroke-linecap: round`, `stroke-linejoin: round`) agar tampak bersahabat bagi pasien lansia.
2. **Motif Cincin & Ritme Konsentris:**
   - Lingkaran ganda pada layar timer (`16.10.40.jpeg`: lingkaran Azure `#00A9EC` dikelilingi cincin Aqua `#1AEAD8`) menjadi ciri kuat yang merepresentasikan ritme/irama (*cadence*) sekaligus cocok untuk metafora **putaran 360°** pada protokol ParkinStep.
3. **Kontras Tinggi Ramah Gangguan Penglihatan & Tremor:**
   - Elemen logo harus memiliki ketebalan garis proporsional (`>= 32–48 px` pada kanvas `1024×1024`) agar tetap tajam dan terbaca pada ukuran ikon status bar (`24 px`) maupun *app icon* (`48 px`).
4. **Tipografi Wordmark:**
   - **Karakter:** Geometric Bold Sans-Serif dengan lekukan huruf terbuka (*open counters*), seperti **Plus Jakarta Sans**, **Nunito**, atau **Poppins** (SemiBold–ExtraBold).
   - **Gaya Lockup Dual-Tone (terinspirasi `"Good Morning, Dave"` & header `BM`):**
     - `Parkin` menggunakan `#234085` (di latar terang, `9.80:1` AAA) atau `#FFFFFF` (di latar gelap, `17.41:1` AAA).
     - `Step` menggunakan `#00A9EC` di latar gelap `#0B1B2B` (`6.54:1` AA), sedangkan **di atas latar putih `#FFFFFF` gunakan `#0077B6` (`4.87:1` AA) atau tetap `#234085`** karena `#00A9EC` murni hanya memiliki rasio `2.66:1` di atas putih.

---

## 3. Diferensiasi Identitas: Beats Medical vs ParkinStep

Logo ParkinStep harus terasa **"satu keluarga estetika"** dengan UI referensi `contoh/`, tetapi **tetap orisinal dan langsung mencerminkan teknologi Mobile-FOG**:

| Aspek | Referensi Beats Medical (`contoh/`) | Identitas Unik **ParkinStep (Mobile-FOG)** |
| :--- | :--- | :--- |
| **Fokus Terapi** | Terapi ritmis audio murni (suara, tangan, jalan) | **Deteksi FoG berbasis kamera AI (6 sendi LB6) + tes putar 360° + RAS cueing** |
| **Simbol Visual** | Inisial `BM` + 5 bar gelombang vertikal | **Gerak langkah/postur tungkai bawah LB6 + lengkung putaran 360° + gelombang langkah Aqua** |
| **Pesan Emosional** | Ketukan irama (*beats*) | **Kebebasan melangkah keluar dari kondisi membeku (*From Freeze to Flow*)** |

---

## 4. Aturan Larangan Keras (*Anti-Patterns*)

1. **DILARANG meniru/menjiplak logo Beats Medical:** Jangan membuat monogram `BM` atau deretan bar equalizer audio vertikal polos sebagai ikon utama ParkinStep.
2. **DILARANG memakai warna merah sebagai warna dominan logo:** Merah membangkitkan kecemasan klinis pada pasien lansia dan bertabrakan dengan warna peringatan bahaya *FoG Alert* di HUD.
3. **DILARANG menggunakan ilustrasi medis klise/menyeramkan:** Hindari tengkorak, otak realistis, jarum suntik, salib medis generik, atau tulang anatomis kaku.
4. **DILARANG memasukkan detail tipis/rumit di App Icon:** Hindari garis `< 20 px` (pada skala `1024 px`), bayangan *drop-shadow* kotor, efek 3D glossy berlebihan, atau tagline teks kecil di dalam ikon launcher.
5. **DILARANG melanggar Safe Zone Adaptive Icon:** Elemen inti ikon tidak boleh melampaui radius `338 px` dari titik pusat `(512, 512)` agar tidak terpotong oleh *mask* lingkaran/squircle Android maupun iOS.
