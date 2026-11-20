# Template Prompt Generasi Logo — ParkinStep (Mobile-FOG)

Gunakan template di bawah ini bersama subagent `image-generator` (atau tool generatif lainnya) untuk mengeksplorasi kandidat visual awal sebelum diubah menjadi master vektor SVG di `resources/svg_grid_template.svg`.

---

## 1. Aturan Penyusunan Prompt
- Selalu kunci palet warna: **Midnight Navy `#0B1B2B`**, **Royal Navy `#234085`**, **Vibrant Azure `#00A9EC`**, **Rhythm Aqua `#1AEAD8`**, dan **Pure White `#FFFFFF`**.
- Selalu minta **flat geometric vector emblem**, **thick clean strokes**, **rounded terminals**, dan **centered composition with generous padding** (agar sesuai *Adaptive Icon Safe Zone 66%*).
- Jangan sertakan kata-kata medis menyeramkan atau tekstur foto.

---

## 2. Prompt 3 Arah Konsep Utama

### Konsep A — *Kinetic Stride `"P"` + RAS Cadence Wave* (Paling Kuat di Skala Kecil)
**Prompt App Icon (Latar Dark Midnight Navy `#0B1B2B`):**
> Minimalist modern medical health-tech app icon logo, flat geometric vector emblem centered with 20% padding on a solid deep midnight navy (#0B1B2B) square background. A bold rounded monogram letter "P" in vibrant azure blue (#00A9EC) where the lower stem seamlessly curves forward into a dynamic stepping stride motion paired with a smooth glowing electric aqua (#1AEAD8) rhythmic wave arc. Rounded stroke caps, balanced negative space, ultra-clean Swiss medical aesthetic, high contrast, friendly and uplifting for elderly Parkinson patients, crisp 2D vector style, no text, no gradients clutter, 1024x1024.

**Prompt App Icon (Latar Putih / Light Variant):**
> Minimalist modern medical health-tech app icon logo, flat geometric vector symbol centered with generous margin on a pure white (#FFFFFF) background. A bold rounded geometric "P" monogram combining clinical royal navy (#234085) and vibrant azure blue (#00A9EC), whose bottom leg extends gracefully into a forward stepping motion accompanied by a smooth rhythm wave in electric aqua (#1AEAD8). Clean rounded terminals, crisp flat vector design, timeless healthcare brand mark, no text, no shadows, 1024x1024.

---

### Konsep B — *Friendly Geometric LB6 Stride Constellation* (Terinspirasi 6 Sendi Tungkai Bawah)
**Prompt App Icon:**
> Minimalist modern digital health app icon, flat vector emblem centered on a solid deep midnight navy (#0B1B2B) background with wide safe margins. An abstract, uplifting silhouette of lower-body walking stride formed by two smooth connected geometric leg lines with subtle glowing joint nodes (hip, knee, ankle) in vibrant azure (#00A9EC) and electric aqua (#1AEAD8), symbolizing effortless forward movement and AI motion tracking. Thick rounded lines, approachable and warm clinical feel, zero realism, no skeleton skull or scary anatomy, ultra-clean flat 2D emblem, 1024x1024.

---

### Konsep C — *360° Turning Motion Ring + Stepping Flow* (Terinspirasi Protokol Putar 360°)
**Prompt App Icon:**
> Minimalist modern health-tech app icon logo, centered on a solid deep midnight navy (#0B1B2B) background with 20% margin. An open circular 360-degree motion ring sweeping smoothly from vibrant azure (#00A9EC) to electric aqua (#1AEAD8), enclosing a stylized minimalist forward-stepping foot-stride curve in crisp white (#FFFFFF) and azure. Represents turning balance and liberation from gait freezing. Bold uniform stroke weight, rounded ends, clean Apple Health / Beats Medical inspired geometric simplicity, pure 2D flat vector, no text, 1024x1024.

---

## 3. Prompt Varian Lockup Horizontal (*Header Splash & Auth*)

Gunakan varian ini hanya untuk eksplorasi tipografi/proporsi lockup di layar Login (`#0B1B2B`) atau Home (`#FFFFFF`); **final wordmark wajib dibuat ulang sebagai SVG presisi** agar ejaan `"ParkinStep"` 100% sempurna.

**Dark Mode Lockup (`#0B1B2B`, setara layar Login di `contoh/`):**
> Clean horizontal brand logo lockup centered on a solid deep midnight navy (#0B1B2B) canvas. On the left, a compact minimalist azure (#00A9EC) and electric aqua (#1AEAD8) rounded kinetic stride "P" emblem. On the right, clean modern bold geometric sans-serif wordmark reading "ParkinStep" where "Parkin" is pure white (#FFFFFF) and "Step" is vibrant azure (#00A9EC). Generous clear space, high-contrast medical accessibility aesthetic, flat 2D vector presentation.

---

## 4. Negative Prompts Wajib (Selalu Sertakan / Cek Saat Kurasi)

Hindari dan tolak kandidat gambar jika mengandung elemen berikut:
> `--no` photorealistic, 3D render, glossy bevel, drop shadow, complex thin lines, anatomical skeleton, skull, brain MRI, syringe, hospital red cross, red dominant color, equalizer vertical bars, letters BM, cluttered background, mockup phone frame, small unreadable text, watercolor, grunge texture.

---

## 5. Panduan Kurasi & Transisi ke Vektor SVG (*Handoff*)

Setelah `image-generator` menghasilkan kandidat:
1. **Tes Skala Mini (24px & 48px):** Perkecil tampilan kandidat hingga ukuran thumbnail kecil. Tolak desain yang garisnya menyatu atau tampak buram.
2. **Sederhanakan Bentuk:** Ambil maksimal **3–5 bentuk primitif** dari konsep terpilih saat menggambar ulang di atas `./resources/svg_grid_template.svg`.
3. **Kunci Warna ke Token DNA:** Ganti warna raster perkiraan menjadi exact HEX (`#0B1B2B`, `#234085`, `#00A9EC`, `#1AEAD8`, `#FFFFFF`) lalu verifikasi via `./scripts/verify_logo_assets.py`.
