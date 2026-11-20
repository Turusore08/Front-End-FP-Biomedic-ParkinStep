import '../../domain/entities/onboarding_status.dart';
import '../../domain/enums/onboarding_auth_mode.dart';
import '../ports/onboarding_repository_port.dart';

/// Marks onboarding entry as offline-first local mode without requiring a login.
class ContinueOfflineLocal {
  const ContinueOfflineLocal(this._repository);

  final OnboardingRepositoryPort _repository;

  Future<OnboardingStatus> execute(OnboardingStatus current) async {
    final nowUtc = DateTime.now().toUtc();
    final updated = current.copyWith(
      authMode: OnboardingAuthMode.offlineLocal,
      displayName:
          current.displayName.trim().isEmpty ? 'Pengguna' : current.displayName,
      updatedAtUtc: nowUtc,
    );
    await _repository.saveStatus(updated);
    return updated;
  }
}
