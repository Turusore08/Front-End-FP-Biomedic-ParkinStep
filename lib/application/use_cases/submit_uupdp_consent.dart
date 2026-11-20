import '../../domain/entities/consent_preferences.dart';
import '../../domain/entities/onboarding_status.dart';
import '../../domain/errors/onboarding_failure.dart';
import '../ports/onboarding_repository_port.dart';

/// Enforces mandatory local processing consent and commits UTC timestamp.
class SubmitUupdpConsent {
  const SubmitUupdpConsent(this._repository);

  final OnboardingRepositoryPort _repository;

  Future<OnboardingStatus> execute({
    required OnboardingStatus current,
    required ConsentPreferences consent,
  }) async {
    if (!consent.canProceed) {
      throw const LocalConsentRequiredFailure();
    }

    final nowUtc = DateTime.now().toUtc();
    final committedConsent = consent.copyWith(acceptedAtUtc: nowUtc);
    final updated = current.copyWith(
      consent: committedConsent,
      updatedAtUtc: nowUtc,
    );
    await _repository.saveStatus(updated);
    return updated;
  }
}
