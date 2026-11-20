# Checklist Audit Aksesibilitas Parkinson & Template Widget Test — ParkinStep

Referensi standar QA untuk [UI_UX_SPEC.md](../../../../docs/UI_UX_SPEC.md) dan [AGENT_RULES.md](../../../../AGENT_RULES.md).

---

## 1. Checklist Audit Pra-Merge

### A. Ergonomi Motorik Tremor & Lansia
- [ ] Seluruh tombol navigasi & header berukuran minimal `56 × 56 dp` (`Semantics` label jelas).
- [ ] Seluruh tombol aksi utama (`ParkinPrimaryPillButton`, `ParkinSecondaryIceButton`, `ParkinStackedMenuTile`) memiliki tinggi `>= 64 dp` dan jarak celah `>= 16 dp`.
- [ ] Tombol pembatalan darurat di layar `S-08` (*Fall Guard*) memiliki tinggi minimal `>= 84 dp`.
- [ ] Tidak ada `Slider`, `RangeSlider`, `Dismissible` (*swipe-to-delete*), atau gestur *pinch-to-zoom* wajib di alur utama pasien.
- [ ] Angka timer, BPM, dan persen FoG menggunakan `FontFeature.tabularFigures()`.

### B. Kontras WCAG 2.1 & Keterbacaan
- [ ] **Nol** teks berukuran normal menggunakan `#00A9EC` atau `#1AEAD8` di atas latar `#FFFFFF` / `#D8F1FC`.
- [ ] Teks biru di atas latar terang memakai `#0077B6` (`4.87:1` AA) atau `#234085` (`9.80:1` AAA).
- [ ] Ukuran font body `>= 16 sp` (minimal absolut `14 sp` untuk caption badge).
- [ ] Seluruh status klinis (`NORMAL GAIT`, `PERINGATAN DINI`, `KAKI MEMBEKU`) menggabungkan **Warna + Ikon + Teks + Audio/Haptic**.

### C. Batas Arsitektur, Keamanan & Identitas Brand
- [ ] File di `lib/presentation/` tidak mengimpor `dart:ffi`, `drift`, `dio`, atau layer `infrastructure/`.
- [ ] Tidak ada logika DSP (`FFT`, `Hampel`, `normalize_lb6`) di dalam widget UI.
- [ ] Tidak ada referensi/teks sisa aplikasi contoh (`Beats Medical`, `BM`, `Nine Hole Peg`, `All letters require a stamp`).
- [ ] *Medical Disclaimer* Bahasa Indonesia tampil pada Onboarding `S-02`, Ringkasan `S-09`, dan ekspor PDF.

---

## 2. Template Widget Test `360 × 640 dp @ 1.5× TextScaler`

Gunakan pola test berikut pada setiap layar utama (`S-01` s.d. `S-10`) di `test/presentation/`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpParkinAccessibilityScreen(
  WidgetTester tester,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 640),
        textScaler: TextScaler.linear(1.5),
      ),
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();

  // Pastikan tidak ada RenderFlex overflow maupun exception rendering
  expect(tester.takeException(), isNull);
}
```
