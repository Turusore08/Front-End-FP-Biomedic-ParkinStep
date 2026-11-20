import '../../domain/entities/consent_preferences.dart';
import '../../domain/entities/onboarding_status.dart';

/// Immutable UI snapshot consumed by S-01, S-02, and router redirects.
class OnboardingUiState {
  const OnboardingUiState({
    this.isInitialized = false,
    this.isSubmitting = false,
    this.status = const OnboardingStatus(),
    this.draftConsent = const ConsentPreferences(),
    this.errorMessage,
    this.isSpeakingGuide = false,
    this.isPreviewSession = false,
  });

  final bool isInitialized;
  final bool isSubmitting;
  final OnboardingStatus status;
  final ConsentPreferences draftConsent;
  final String? errorMessage;
  final bool isSpeakingGuide;
  final bool isPreviewSession;

  OnboardingUiState copyWith({
    bool? isInitialized,
    bool? isSubmitting,
    OnboardingStatus? status,
    ConsentPreferences? draftConsent,
    String? errorMessage,
    bool clearError = false,
    bool? isSpeakingGuide,
    bool? isPreviewSession,
  }) {
    return OnboardingUiState(
      isInitialized: isInitialized ?? this.isInitialized,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      status: status ?? this.status,
      draftConsent: draftConsent ?? this.draftConsent,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSpeakingGuide: isSpeakingGuide ?? this.isSpeakingGuide,
      isPreviewSession: isPreviewSession ?? this.isPreviewSession,
    );
  }
}
