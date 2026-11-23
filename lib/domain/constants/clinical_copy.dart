/// Authoritative clinical, regulatory, and patient-facing Indonesian copy
/// aligned with docs/DATA_PRIVACY_AND_CLINICAL_SAFETY.md and docs/UI_UX_SPEC.md.
abstract final class ClinicalCopy {
  /// Verbatim Indonesian Medical Disclaimer (Section 1.3).
  static const String medicalDisclaimer =
      'PERHATIAN MEDIS: ParkinStep merupakan alat bantu skrining dan '
      'pemantauan mandiri gejala Freezing of Gait (FoG) berbasis kecerdasan '
      'buatan. Hasil deteksi, skor indeks, dan grafik pada aplikasi ini '
      'BUKAN merupakan diagnosis medis resmi dan tidak dapat dijadikan dasar '
      'perubahan dosis obat tanpa persetujuan dokter spesialis saraf. Jika '
      'pasien mengalami jatuh, cedera, atau gejala memburuk secara mendadak, '
      'segera hubungi tenaga medis atau layanan gawat darurat setempat.';

  static const String welcomeTitle = 'Selamat Datang';
  static const String welcomeSubtitle =
      'Kami senang Anda di sini. Masuk untuk menyinkronkan laporan ke dokter '
      'saraf, atau lanjutkan secara offline langsung di ponsel Anda.';
  static const String welcomePrivacyNote =
      'Privasi data adalah prioritas kami. Video kamera diproses secara lokal '
      'dan tidak dikirim tanpa persetujuan Anda.';

  static const String consentScreenTitle = 'Privasi & Keselamatan';
  static const String consentScreenSubtitle =
      'Atur izin pemrosesan data sesuai UU PDP No. 27/2022 sebelum memulai '
      'skrining.';

  static const String consentLocalTitle = 'Analisis Kamera Lokal';
  static const String consentLocalDesc =
      'Video diproses langsung di HP dan langsung dihapus setelah sendi terbaca.';

  static const String consentSyncTitle = 'Bagikan Ringkasan ke Dokter';
  static const String consentSyncDesc =
      'Kirim angka skor FoG, sendi anonim, dan log obat saat internet aktif.';

  static const String consentAuditTitle = 'Audit Video Cadangan';
  static const String consentAuditDesc =
      'Default mati. Hanya mengirim klip sementara jika perangkat gagal membaca pose.';

  static const String helpDialogTitle = 'Bagaimana ParkinStep Bekerja?';
  static const String helpVoiceSummary =
      'ParkinStep membantu memantau langkah kaki penyandang Parkinson menggunakan '
      'kamera ponsel biasa. Video diproses langsung di perangkat Anda dan otomatis '
      'dihapus. Anda dapat masuk dengan akun dokter atau memilih Mode Offline Lokal '
      'tanpa internet. Pada halaman berikutnya, silakan baca Perhatian Medis dan '
      'aktifkan izin kamera lokal untuk memulai.';

  // S-03 Home Dashboard & Navigation Shell
  static const String dashboardStartSectionTitle = 'Pilih untuk Memulai';
  static const String dashboardRecentSessionsTitle = 'Sesi Terakhir';
  static const String reminderTitle = 'Sudah siap latihan tes hari ini?';
  static const String reminderBody =
      'Pilih salah satu dari 3 tes video 2 menit (Berputar, Jalan Bolak-Balik, atau Duduk-Berdiri).';
  static const String emptyHistoryTitle = 'Belum ada riwayat sesi';
  static const String emptyHistoryBody =
      'Selesaikan satu rekaman tes 2 menit lalu tekan Kirim agar Pose Extractor menghitung skor FoG secara lokal.';
  static const String emptyHistoryCta = 'Mulai Tes Pertama';
  static const String privacyShieldTitle = 'Perlindungan Privasi & Data';
  static const String privacyShieldGuarantee =
      'Video rekaman diproses langsung oleh Pose Extractor di ponsel Anda dan otomatis dihapus segera setelah analisis selesai.';
  static const String helpVoiceGuideDetail =
      'Panduan penggunaan ParkinStep berbasis video. Pertama, pilih salah satu dari tiga jenis tes dua menit, yaitu Tes Berputar 360 derajat, Tes Berjalan Bolak-Balik, atau Tes Duduk Berdiri. Kedua, posisikan ponsel setinggi pinggang pada jarak dua hingga tiga meter agar pinggul sampai mata kaki terlihat penuh. Ketiga, ikuti aba-aba suara dan teks saat merekam, lalu tekan Kirim setelah selesai agar Pose Extractor memproses video langsung di ponsel dan menghapus video secara otomatis.';

  // Test Selection Screen
  static const String testSelectionTitle = 'Pilih Jenis Tes';
  static const String testSelectionSubtitle =
      'Pilih satu protokol tes 2 menit yang akan direkam lalu dianalisis secara lokal.';
  static const String testSelectionVoiceGuide =
      'Silakan pilih salah satu dari tiga tes berikut: Tes Berputar 360 derajat selama dua menit, Tes Berjalan Bolak-Balik selama dua menit, atau Tes Duduk Berdiri selama dua menit.';

  // S-04 Pre-Flight Safety Checklist
  static const String preflightTitle = 'Keselamatan Sebelum Tes';
  static const String preflightSubtitle =
      'Pastikan 4 syarat aman berikut sebelum mengarahkan kamera untuk merekam tes.';
  static const String preflightFloorTitle = 'Lingkungan Lantai Aman';
  static const String preflightFloorDesc =
      'Lantai kering, rata, bebas kabel, atau karpet terlipat.';
  static const String preflightSpaceTitle = 'Ruang Gerak Bebas 1,5 m';
  static const String preflightSpaceDesc =
      'Tersedia area kosong minimal radius 1,5 meter untuk bergerak aman.';
  static const String preflightSupportTitle = 'Kursi atau Pendamping Siap';
  static const String preflightSupportDesc =
      'Ada penopang kokoh atau pendamping di luar pusat layar.';
  static const String preflightAttireTitle = 'Pakaian & Posisi Kamera';
  static const String preflightAttireDesc =
      'Alas kaki tidak licin dan tungkai terlihat jelas dari pinggul ke mata kaki.';
  static const String preflightVoiceGuide =
      'Panduan keselamatan sebelum tes. Pertama, pastikan lantai kering dan bebas kabel. Kedua, sisakan ruang gerak aman tanpa rintangan. Ketiga, siapkan kursi kokoh atau pendamping di dekat Anda. Keempat, pilih alas kaki yang aman dan pastikan pinggul hingga mata kaki terlihat kamera. Terakhir, pilih status obat ON atau OFF sebelum menekan Lanjut ke Kamera.';

  // S-07 RAS Metronome
  static const String metronomeHelpTitle = 'Cara Menggunakan Metronom RAS';
  static const String metronomeHelpBody =
      'Stimulasi auditori ritmis membantu mengembalikan irama langkah kaki saat '
      'mulai terasa tertahan. Atur tempo 40 hingga 120 ketukan per menit dengan '
      'dua tombol belah ketupat besar, lalu tekan Mulai Metronom dan angkat '
      'lutut mengikuti setiap ketukan.';
  static const String metronomeVoiceGuide =
      'Metronom ritmis ParkinStep membantu memberi aba-aba ketukan teratur. '
      'Gunakan tombol panah atas atau bawah untuk mengatur kecepatan antara '
      '40 sampai 120 ketukan per menit, lalu tekan Mulai Metronom untuk '
      'mendengarkan irama langkah.';

  // Video Recording, Confirmation, Pose Extraction & State Cards
  static const String readyToRecordTitle = 'Siap Merekam Video Tes';
  static const String readyToRecordBody =
      'Posisikan pinggul sampai mata kaki di dalam bingkai, lalu tekan Mulai Rekam dan ikuti perintah di layar.';
  static const String reviewRecordedTitle = 'Rekaman Selesai';
  static const String reviewPrivacyGuarantee =
      'Video hanya disimpan sementara di HP ini dan akan otomatis dihapus permanen begitu analisis selesai.';
  static const String reviewShortVideoWarning =
      'Durasi rekaman kurang dari 3 detik. Silakan ulangi rekaman minimal 3 detik agar analisis FoG valid.';

  static const String errorLowLightTitle = 'Analisis video tidak dapat dilanjutkan';
  static const String errorLowLightBody =
      'Pastikan pencahayaan ruangan terang, tubuh terlihat penuh 2-3 meter dari kamera, lalu rekam ulang.';
  static const String errorLowLightCta = 'Rekam Ulang';

  static const String loadingDspTitle = 'Mengekstrak pose dari video...';
  static const String loadingDspBody =
      'Pose Extractor menganalisis gerakan secara offline di HP Anda dan otomatis menghapus video sementara setelah selesai.';

  // S-06 Two-Tier Highlight Prompts
  static const String livePromptNormalHighlight = 'BERPUTAR PERLAHAN';
  static const String livePromptNormalTail = 'jaga langkah tetap stabil';
  static const String livePromptWarningHighlight = 'TETAP TENANG';
  static const String livePromptWarningTail = 'siapkan langkah lebar berikutnya';
  static const String livePromptFogHighlight = 'ANGKAT LUTUT';
  static const String livePromptFogTail = 'ikuti ketukan suara';
  static const String liveFogVoicePrompt =
      'Berhenti sejenak. Tarik napas. Langkahkan kaki ikuti ketukan suara.';

  // S-08 Fall Guard
  static const String fallGuardTopLabel = 'Perlindungan Keselamatan Aktif';
  static const String fallGuardTitle = 'Apakah Anda baik-baik saja?';
  static const String fallGuardBody =
      'Tekan tombol hijau besar di bawah jika Anda aman agar sirine darurat tidak dibunyikan.';
  static const String fallGuardImOkCta = 'Saya Baik-Baik Saja';
  static const String fallGuardVoicePrompt =
      'Apakah Anda baik-baik saja? Tekan tombol hijau besar di layar dalam 10 detik jika Anda aman.';

  // S-09 Clinical Summary & S-10 Medication Trend
  static const String reportScreenTitle = 'Ringkasan Hasil Sesi';
  static const String reportTimelineTitle = 'Kapan kaki membeku (0-120 dtk)?';
  static const String reportSpectrumTitle =
      'Energi langkah normal vs getaran FoG (FFT)';
  static const String reportZeroEpisodeBadge = 'Tidak Terdeteksi Episode FoG';
  static const String historyScreenTitle = 'Riwayat & Tren Obat';
  static const String historyModelMetadata =
      'Model Aktif: LightGBM+FFT v2026.11 (Skenario B 15 Hz · Ambang 0,26)';
}
