import '../enums/onboarding_auth_mode.dart';
import '../enums/user_role.dart';
import 'consent_preferences.dart';

/// Persisted onboarding snapshot across S-01 (auth choice) and S-02 (consent).
class OnboardingStatus {
  const OnboardingStatus({
    this.authMode,
    this.consent = const ConsentPreferences(),
    this.displayName = 'Pengguna',
    this.role = UserRole.patient,
    this.updatedAtUtc,
  });

  final OnboardingAuthMode? authMode;
  final ConsentPreferences consent;
  final String displayName;
  final UserRole role;
  final DateTime? updatedAtUtc;

  /// True once the user picked an auth mode and confirmed valid UU PDP consent.
  bool get isCompleted =>
      authMode != null && consent.canProceed && consent.acceptedAtUtc != null;

  OnboardingStatus copyWith({
    OnboardingAuthMode? authMode,
    bool clearAuthMode = false,
    ConsentPreferences? consent,
    String? displayName,
    UserRole? role,
    DateTime? updatedAtUtc,
    bool clearUpdatedAt = false,
  }) {
    return OnboardingStatus(
      authMode: clearAuthMode ? null : (authMode ?? this.authMode),
      consent: consent ?? this.consent,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      updatedAtUtc:
          clearUpdatedAt ? null : (updatedAtUtc ?? this.updatedAtUtc),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingStatus &&
        other.authMode == authMode &&
        other.consent == consent &&
        other.displayName == displayName &&
        other.role == role &&
        other.updatedAtUtc == updatedAtUtc;
  }

  @override
  int get hashCode =>
      Object.hash(authMode, consent, displayName, role, updatedAtUtc);
}
