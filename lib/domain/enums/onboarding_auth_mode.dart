/// Authentication mode selected during ParkinStep onboarding.
enum OnboardingAuthMode {
  account('ACCOUNT', 'Akun Terhubung'),
  offlineLocal('OFFLINE_LOCAL', 'Mode Offline Lokal');

  const OnboardingAuthMode(this.wireValue, this.labelId);

  /// Stable uppercase string enum serialized across local storage and APIs.
  final String wireValue;

  /// Human-readable Indonesian label displayed in UI summaries.
  final String labelId;

  static OnboardingAuthMode? fromWire(String? value) {
    if (value == null) return null;
    for (final mode in values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
}
