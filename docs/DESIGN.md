# Design Direction: ParkinStep (Mobile-FOG)

- **Dial: ENERGY 2 / RHYTHM 2 / MOTION 2**
- **Design Read:** `Reading this as: clinical Parkinson's mobile gait-screening and acoustic cueing app for older adults (60+) and caregivers, in a Beats-Medical-inspired high-clarity clinical calm language, dial ENERGY 2 / RHYTHM 2 / MOTION 2.`
- **Referensi Visual:** 5 tangkapan layar aplikasi terapi Parkinson **Beats Medical** pada folder [contoh/](../contoh/), diadaptasi 100% ke identitas merek **ParkinStep (Konsep A: P+S Kinetic Stride)** tanpa menyalin elemen atau teks merek referensi.

---

## 1. Jiwa & Karakter Produk

Pengguna utama ParkinStep adalah penyandang Parkinson berusia lanjut (`60+ tahun`) yang mengalami tremor tangan, kelambatan inisiasi langkah (*bradikinesia*), dan kecemasan saat berputar di tempat, bersama pendamping/keluarga mereka. Aplikasi harus terasa **tenang secara klinis, tegas pada keterbacaan, hangat saat memandu, namun tetap modern dan berwibawa**, bukan terasa seperti purwarupa mahasiswa atau template generik bertema neon teknologi.

### Lima Pengungkit Keterbacaan & Nyawa Desain (*Liveliness Levers*)
1. **Satu Titik Fokus per Layar:** Setiap layar memiliki tepat satu elemen paling menonjol (misalnya 3 kartu aksi di `S-03`, cincin metronom `02:00` di `S-07`, tombol hijau raksasa pembatal di `S-08`, atau skeleton LB6 + prompt instruksi di `S-06`).
2. **Kontras Hierarki Tegas:** Tipografi `Plus Jakarta Sans` memakai pembobotan dan *tracking* yang dibedakan sengaja (`-2%` pada angka/judul besar agar padat meyakinkan, `0%` pada bodi `16px+` dengan jarak baris lapang `1.45` untuk mata lansia, serta angka *tabular* untuk timer dan skor).
3. **Ruang Kosong Struktural (*Whitespace as Structure*):** Layar onboarding (`S-01`), persiapan (`S-04`), dan metronom (`S-07`) menggunakan ruang kosong terukur di antara blok informasi atas dan tombol tindakan bawah agar aksi berada di zona ibu jari tanpa terasa penuh sesak.
4. **Satu Aksen Terarah:** `brand/rhythm-aqua` (`#1AEAD8`) dicadangkan khusus untuk menandai momen ritme atau status aktif (lingkaran luar metronom RAS, blok sorotan kata kunci gerak *"ANGKAT LUTUT"*, bar progres sesi, dan kartu ringkas terbaru di carousel).
5. **Motif Identitas Khas (`contoh/` -> ParkinStep):**
   - **Ikon Lingkaran Putih di Kiri Pil Aksi:** Tombol pil utama (`64px`) membawa lingkaran putih `46×46px` berisi ikon kontekstual di sisi kiri.
   - **Ubin Ilustrasi Squircle Miring Lembut:** Kartu fitur vertikal beranda membungkus ilustrasi garis halus di atas ubin putih bersudut membulat dengan rotasi tipis `-5° / +3.5° / -5°`.
   - **Kontrol Belah Ketupat `45°`:** Penyesuaian BPM/durasi pada metronom memakai dua tombol persegi membulat Royal Navy (`#234085`) yang diputar `45°` dengan ikon chevron tegak, menggantikan slider tipis yang mustahil dipakai penderita tremor.
   - **Cincin Progres Mengintip pada Carousel:** Kartu riwayat di beranda memakai warna bervariasi (`Mint #1AEAD8`, `Sky #BAE6FD`, `Azure #0077B6`) dengan busur progres melingkar yang mengintip rapi dari tepi bawah kartu.

---

## 2. Sistem Warna Terverifikasi WCAG 2.1 (3 Warna Inti + 1 Aksen)

Seluruh pasangan teks dan latar diverifikasi menggunakan `contrast-check.py` berbasis rumus luminansi WCAG 2.x.

### Warna Inti & Aksen
| Peran | Token Figma | HEX | Rasio Kontras Terukur | Aturan Pakai |
| :--- | :--- | :---: | :---: | :--- |
| Inti 1 (Gelap) | `bg/dark-canvas` | `#0B1B2B` | `17.41:1` (AAA vs `#FFFFFF`) | Kanvas layar Auth (`S-01`), Kamera (`S-05/06`), & Fall Guard (`S-08`). |
| Inti 1 (Elevasi Gelap) | `bg/dark-elevated` | `#13263B` | `14.5:1` (AAA vs `#FFFFFF`) | Panel HUD bawah terangkat pada `S-06` dan kartu ringkas di atas gelap. |
| Inti 2 (Wibawa Klinis) | `brand/royal-navy` | `#234085` | `9.80:1` (AAA vs `#FFFFFF`) | Judul layar terang, tombol diamond stepper, kartu pengingat gelap, jarum gauge, teks PDF. |
| Inti 3 (Aksi & Kartu) | `brand/clinical-azure` | `#0077B6` | `4.87:1` (AA vs `#FFFFFF`) | Latar tombol CTA berteks putih, kartu fitur vertikal, kartu checklist terpilih, kurva garis utama. |
| Aksen Kinetik Tunggal | `brand/rhythm-aqua` | `#1AEAD8` | `11.45:1` (AAA vs `#0B1B2B`), `6.44:1` (AA vs `#234085`) | Cincin pulse metronom, isi bar progres, blok sorotan kata perintah gerak, kartu carousel pertama. |
| Variasi Grafis Non-Teks | `brand/vibrant-azure` | `#00A9EC` | `6.54:1` (AA vs `#0B1B2B`) | **Hanya** ikon non-teks, garis aksen ilustrasi, tanda baca `"Step"` pada lockup latar gelap, dan poros jarum gauge. |

### Permukaan Terang & Semantik Klinis (Selalu Didampingi Ikon + Teks)
- **Netral Terang:** `bg/pure-white` `#FFFFFF`, `bg/light-canvas` `#F8FAFC`, `border/subtle-light` `#E2E8F0`, `border/subtle-dark` `#1F3852`.
- **Permukaan Es & Teks Aman:** `surface/soft-ice` `#D8F1FC`, `surface/ice-tint` `#E8F7FC`, `surface/sky-card` `#BAE6FD`, dengan teks `text/on-ice-azure` `#006299` (`5.58:1` AA vs `#D8F1FC`) atau `brand/royal-navy` `#234085` (`8.35:1` AAA).
- **Teks Sekunder:** `text/secondary-light` `#475569` (`7.58:1` AAA vs `#FFFFFF`, `6.46:1` AAA vs `#D8F1FC`), `text/muted-nav` `#64748B` (`4.76:1` AA vs `#FFFFFF`), `text/secondary-dark` `#CBD5E1` (`11.73:1` AAA vs `#0B1B2B`).
- **Semantik Klinis:**
  - Normal: `semantic/normal` `#22D399` (teks gelap `#0B1B2B` `8.99:1` AAA; lencana terang `#065F46` di atas `#D1FAE5` `6.78:1`).
  - Peringatan / OFF Obat: `semantic/warning` `#F59E0B` (`8.11:1` AAA vs `#0B1B2B`), `semantic/warning-text` `#B45309` (`5.02:1` AA vs `#FFFFFF`), kotak disclaimer `#FFFBEB` / border `#FDE68A` / teks `#92400E` (`6.84:1` AAA).
  - FoG Aktif / Bahaya Fall Guard: `semantic/alert-red` `#DC2626` (`4.83:1` AA vs `#FFFFFF`), soft card `#FEF2F2` / teks `#991B1B` (`7.60:1` AAA).

---

## 3. Catatan Keputusan R-31 (Satu Baris per Keputusan Utama)

- **Mengapa warna ini (`#0B1B2B`, `#234085`, `#0077B6`, `#1AEAD8`):** Kanvas terang memberi ketenangan klinis harian sementara `#0B1B2B` mengurangi silau saat kamera aktif dan mengunci kontras tinggi di layar darurat, dengan `#0077B6` menjamin kontras putih `>= 4.5:1` (WCAG AA) dan `#1AEAD8` menandai ketukan ritmis RAS.
- **Mengapa tipografi `Plus Jakarta Sans` dengan angka tabular:** Bentuk geometris bersudut sedikit membulat tetap humanis bagi lansia, bobot ExtraBold hingga Regular memberi jenjang jelas, dan angka tabular mencegah timer `02:00` atau `00:58` bergetar saat diperbarui tiap detik.
- **Mengapa layout bertumpu pada zona ibu jari dan tinggi target >= 56–64 dp:** Pasien Parkinson dengan tremor atau bradikinesia membutuhkan tombol lebar penuh berketinggian minimum `64 dp` (`88 dp` di layar darurat `S-08`) yang berada konsisten di paruh bawah layar tanpa slider tipis atau gestur geser.
- **Mengapa kartu bervariasi alih-alih satu template kartu seragam:** Tiga kartu fitur beranda memakai struktur ubin vertikal yang ringkas, pengingat harian memakai kartu gelap aksi-ganda, status terakhir memakai pil horizontal bergredasi lembut, dan riwayat sesi memakai kartu berwarna dengan cincin progres, mencerminkan perbedaan fungsi tiap blok (R-14).
- **Mengapa radius terkendali (`16 / 18 / 20 / 24 / 999`) dan bayangan selektif (`Shadow/AzureCTA` hanya pada CTA & kartu aksi):** Pembedaan radius memisahkan kontainer halaman, kartu konten, tombol tindakan, dan bar progres kapsul, sementara bayangan biru hanya mengangkat elemen yang dapat ditekan langsung oleh pengguna (R-11, R-12).
- **Mengapa ilustrasi garis medis & foto ruang pasien nyata di kamera:** Tiga ilustrasi unik membedakan Tes Putar 360°, Metronom RAS, dan Log Obat dalam sekilas pandangan tanpa tebak-tebakan ikon generik, dan foto ruang nyata di `S-05`/`S-06` menunjukkan konteks pemasangan kamera rumah `2–3 m` serta proyeksi sendi LB6 nyata.
- **Mengapa motion disetel pada dial `2` (terarah, tanpa loop hiasan):** Animasi dibatasi pada denyut cincin metronom yang tersinkron langsung dengan ketukan `60–110 BPM` dan transisi cincin hitung mundur kalibrasi/darurat, menghormati pengaturan `prefers-reduced-motion` (R-19).
