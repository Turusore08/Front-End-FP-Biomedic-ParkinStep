import '../../domain/entities/onboarding_status.dart';

/// Port for offline-first storage of authentication choice & UU PDP consents.
abstract interface class OnboardingRepositoryPort {
  Future<OnboardingStatus> loadStatus();
  Future<void> saveStatus(OnboardingStatus status);
  Future<void> clearStatus();
}
