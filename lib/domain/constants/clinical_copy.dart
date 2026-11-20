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
  static const String reminderTitle = 'Sudah siap latihan langkah hari ini?';
  static const String reminderBody =
      'Tes putar 360° selama 2 menit membantu memantau gejala FoG harian '
      'secara objektif.';
  static const String emptyHistoryTitle = 'Belum ada riwayat sesi';
  static const String emptyHistoryBody =
      'Selesaikan satu Tes 360° selama 2 menit agar skor FoG dan perbandingan '
      'ON/OFF obat mulai tercatat di perangkat ini.';
  static const String emptyHistoryCta = 'Mulai Tes Pertama';
  static const String privacyShieldTitle = 'Perlindungan Privasi & Data';
  static const String privacyShieldGuarantee =
      'Video kamera diproses langsung di ponsel Anda dan otomatis dihapus '
      'segera setelah titik sendi terbaca.';
  static const String helpVoiceGuideDetail =
      'Panduan penggunaan ParkinStep. Pertama, letakkan ponsel setinggi '
      'pinggang pada jarak 2 hingga 3 meter dengan pencahayaan ruangan yang '
      'terang agar pinggul hingga pergelangan kaki terlihat penuh. Kedua, catat '
      'status obat Levodopa ON atau OFF sebelum tes agar dokter dapat menilai '
      'pengaruh obat terhadap gejala langkah membeku. Ketiga, seluruh video '
      'kamera dianalisis langsung di ponsel dan otomatis dihapus setelah titik '
      'sendi terbaca.';
}
