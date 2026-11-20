# Token Desain & Katalog Komponen Baku v2: ParkinStep

Referensi implementasi `ThemeData` Flutter dan Variabel Figma v2 yang diselaraskan dari [DESIGN.md](../../../../docs/DESIGN.md), [UI_UX_SPEC.md](../../../../docs/UI_UX_SPEC.md), dan hasil audit `anti-slop`.

---

## 1. Token Warna Terverifikasi WCAG 2.1 & Pemetaan Figma Variable

| Token Dart (`AppColors`) | Nama Variabel Figma | HEX | Kontras Terukur | Aturan Pakai Ketat |
| :--- | :--- | :---: | :---: | :--- |
| `midnightNavy` | `bg/dark-canvas` | `#0B1B2B` | `17.41:1` vs `#FFFFFF` | Latar S-01 Auth, S-05/06 Kamera, S-08 Fall Guard |
| `darkElevated` | `bg/dark-elevated` | `#13263B` | `14.50:1` vs `#FFFFFF` | Panel HUD bawah terangkat (`S-06`) & kartu gelap |
| `royalNavy` | `brand/royal-navy` | `#234085` | `9.80:1` vs `#FFFFFF` | Heading terang, tombol diamond `45°`, banner gelap, PDF mono |
| `clinicalAzure` | `brand/clinical-azure` | `#0077B6` | `4.87:1` vs `#FFFFFF` | Latar utama tombol CTA berteks putih, 3 kartu beranda, item tercentang |
| `vibrantAzure` | `brand/vibrant-azure` | `#00A9EC` | `6.54:1` vs `#0B1B2B` | **Khusus** ikon non-teks, aksen ilustrasi, poros gauge, & `"Step"` di latar gelap |
| `onIceAzure` | `text/on-ice-azure` | `#006299` | `5.58:1` vs `#D8F1FC` | Teks link/tombol sekunder di atas `#D8F1FC` dan `#FFFFFF` (`6.40:1`) |
| `rhythmAqua` | `brand/rhythm-aqua` | `#1AEAD8` | `11.45:1` vs `#0B1B2B` | **Satu aksen terarah:** cincin metronom, bar progres, sorotan kata gerak, kartu Mint |
| `softIce` | `surface/soft-ice` | `#D8F1FC` | `8.35:1` (#234085) | Tombol sekunder, gradien pil metrik beranda |
| `iceSurface` | `surface/ice-tint` | `#E8F7FC` | - | Badge ikon header (`?`, perisai, suara) & tile belum tercentang |
| `skyCard` | `surface/sky-card` | `#BAE6FD` | `7.38:1` (#234085) | Kartu carousel Sky & border item belum tercentang |
| `pureWhite` | `bg/pure-white` | `#FFFFFF` | `17.41:1` (#0B1B2B) | Kanvas utama terang, ubin ilustrasi, teks di atas `#0077B6`/`#234085` |
| `slateCanvas` | `bg/light-canvas` | `#F8FAFC` | - | Latar *Scaffold* formulir, riwayat & laporan |
| `subtleBorderLight` | `border/subtle-light` | `#E2E8F0` | - | Hairline divider & border `1 dp` kartu putih |
| `subtleBorderDark` | `border/subtle-dark` | `#1F3852` | - | Hairline divider di atas `#0B1B2B` |
| `mutedSlate` | `text/secondary-light` | `#475569` | `7.58:1` vs `#FFFFFF` | Teks subjudul di atas terang & `#D8F1FC` (`6.46:1`) |
| `mutedNavSlate` | `text/muted-nav` | `#64748B` | `4.76:1` vs `#FFFFFF` | Label bottom nav nonaktif & angka sumbu grafik |
| `darkMuted` | `text/secondary-dark` | `#CBD5E1` | `11.73:1` vs `#0B1B2B` | Teks subjudul di atas `#0B1B2B` |
| `normalEmerald` | `semantic/normal` | `#22D399` | `8.99:1` vs `#0B1B2B` | Status `NORMAL GAIT`, tulang LB6 aman, CTA batal Fall Guard |
| `warningAmber` | `semantic/warning` | `#F59E0B` | `8.11:1` vs `#0B1B2B` | Peringatan dini & penanda visual (`#B45309` untuk teks di putih `5.02:1`) |
| `alertRed` | `semantic/alert-red` | `#DC2626` | `4.83:1` vs `#FFFFFF` | Status `KAKI MEMBEKU`, tulang LB6 membeku, Fall Guard, FFT `3–7,35 Hz` |
| `upperBodySky` | `hud/upper-skeleton` | `#38BDF8` | - | Garis upper body (`0..10`) di overlay kamera |

---

## 2. Tipografi, Radius, Spasi & Elevasi Selektif

- **Font:** `Plus Jakarta Sans` (`Regular`, `Medium`, `SemiBold`, `Bold`, `ExtraBold`); wajib `FontFeature.tabularFigures()` pada timer, BPM, FPS, dan persen FoG. Dilarang `Inter`.
- **Skala & Tracking:** `displayTimer` (`48–56 sp` ExtraBold, `-2%`), `heroMetric` (`28–34 sp` ExtraBold, `-2%`), `screenTitle` (`24–28 sp` ExtraBold, `-2%`), `cardTitle` (`18–20 sp` Bold, `-1%`), `buttonLabel` (`16–18 sp` Bold), `bodyLarge` (`15–16 sp` Medium/Regular, `1.45` line-height), `captionBadge` (`12–13 sp` SemiBold).
- **Radius:** Kartu utama `20–22 dp`; tombol pil & ubin miring `18 dp`; kotak status & tombol diamond `16 dp`; progress pill & chip `999 dp`.
- **Elevasi & Glow Selektif:**
  - `Shadow/AzureCTA`: `0 10 24` (`#0077B6`, 28%) **hanya** untuk CTA primer & 3 kartu fitur beranda.
  - `Shadow/CardSubtle`: `0 4 14` (`#0B1B2B`, 6%) untuk kartu konten di atas `#F8FAFC`.
  - `Shadow/DiamondControl`: `0 8 18` (`#0B1B2B`, 34%) untuk tombol stepper diamond `45°`.
  - `Glow/RhythmAqua`: `0 0 24` (`#1AEAD8`, 24%) **khusus** untuk `ParkinPulseMetronomeRing`.

---

## 3. Spesifikasi Komponen Wajib (`lib/presentation/widgets/design_system/`)

1. **`ParkinPrimaryPillButton`** *(Ref `16.10.35`, `16.10.40`):* Tinggi `64 dp`, fill `#0077B6`, `Shadow/AzureCTA`, lingkaran putih `46 dp` kiri berisi ikon `#0077B6`, label `#FFFFFF` `17–18 sp` Bold.
2. **`ParkinSecondaryIceButton`** *(Ref `16.10.35`):* Tinggi `64 dp`, fill `#D8F1FC`, lingkaran putih `46 dp` kiri berisi ikon `#006299`, judul `#006299` `16 sp` Bold + subjudul `#475569` `13 sp`.
3. **`ParkinVerticalFeatureCard`** *(Ref `16.10.42`):* 3 kartu sejajar (`108×158 dp`), fill `#0077B6`, `Shadow/AzureCTA`, ubin putih miring (`82×82 dp`, `-5° / +3.5° / -5°`) berisi **3 ilustrasi line-art unik**, label putih `15 sp` Bold.
4. **`ParkinStackedMenuTile`** *(Ref `16.10.40 (2)`):* Baris penuh `64 dp`, gap `12 dp`, ikon berbeda tiap baris dalam lingkaran putih kiri; varian terpilih `#0077B6` vs belum dipilih `#E8F7FC` (`1 dp #BAE6FD`).
5. **`ParkinConsentToggleCard`:** Tinggi `76 dp`, fill `#FFFFFF`, border `1 dp #E2E8F0`, radius `16 dp`, saklar fisik `56×32 dp` (`#0077B6` vs `#CBD5E1`).
6. **`ParkinMetricPill`:** Tinggi `84 dp`, gradien `#EBF8FE -> #D8F1FC`, ikon sepatu dalam lingkaran kiri, angka `28 sp` ExtraBold `#234085` di kanan.
7. **`ParkinDarkReminderCard`:** Latar `#234085`, radius `22 dp`, teks putih `15–16 sp`, tombol outline `Lewati` + pil `#0077B6` `Mulai >`.
8. **`ParkinSessionCarouselCard`:** 3 varian (`Mint`, `Sky`, `Azure`), `108×132 dp`, `clipsContent = true`, membawa cincin progres putih+warna mengintip di tepi bawah.
9. **`ParkinPulseMetronomeRing`:** Ring luar `#1AEAD8` (`Glow/RhythmAqua`) + lingkaran dalam `#0077B6` + timer tabular + **2 tombol diamond `45°` `#234085` `64×64 dp`** berbayangan dengan chevron putih tegak.
10. **`ParkinRiskGauge` + `ParkinHighlightPrompt` + `ParkinProgressPill` + `ParkinBottomNav` + `State/*`:** Gauge 3 zona bertanda `0..100`, prompt putih berblok `#1AEAD8`, progress kapsul berborder `#234085`, bottom nav 4 tab tanpa pemotongan (`BERANDA | RIWAYAT | BANTUAN | PENGATURAN`), dan 3 komponen state wajib (`EmptyHistory`, `LoadingDSP`, `ErrorLowLight`).
