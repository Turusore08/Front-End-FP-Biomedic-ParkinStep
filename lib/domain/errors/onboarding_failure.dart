/// Domain-level failures surfaced during ParkinStep onboarding & consent.
sealed class OnboardingFailure implements Exception {
  const OnboardingFailure(this.userMessageId);

  /// Elderly-friendly Indonesian explanation shown with an explicit icon.
  final String userMessageId;
}

final class InvalidIdentifierFailure extends OnboardingFailure {
  const InvalidIdentifierFailure()
      : super(
          'Masukkan alamat email yang valid atau nomor HP minimal 8 digit.',
        );
}

final class WeakPasswordFailure extends OnboardingFailure {
  const WeakPasswordFailure()
      : super('Kata sandi minimal terdiri dari 8 karakter.');
}

final class LocalConsentRequiredFailure extends OnboardingFailure {
  const LocalConsentRequiredFailure()
      : super(
          'Izin kamera lokal wajib diaktifkan agar deteksi FoG dapat berjalan.',
        );
}

final class StorageFailure extends OnboardingFailure {
  const StorageFailure()
      : super(
          'Gagal menyimpan pengaturan ke memori perangkat. Silakan coba lagi.',
        );
}

final class BackendNotConfiguredFailure extends OnboardingFailure {
  const BackendNotConfiguredFailure()
      : super(
          'Server sinkronisasi belum terhubung pada build ini. Gunakan Mode Offline Lokal untuk langsung memulai.',
        );
}
