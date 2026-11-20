import '../../domain/entities/onboarding_status.dart';
import '../../domain/enums/onboarding_auth_mode.dart';
import '../../domain/errors/onboarding_failure.dart';
import '../ports/auth_gateway_port.dart';
import '../ports/onboarding_repository_port.dart';

/// Validates credentials and signs the user in via AuthGatewayPort.
class SignInWithAccount {
  const SignInWithAccount({
    required this.authGateway,
    required this.repository,
  });

  final AuthGatewayPort authGateway;
  final OnboardingRepositoryPort repository;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneDigitsPattern = RegExp(r'^\+?[0-9]{8,15}$');

  Future<OnboardingStatus> execute({
    required OnboardingStatus current,
    required String identifier,
    required String password,
    required String deviceId,
  }) async {
    final trimmedId = identifier.trim();
    final compactPhone = trimmedId.replaceAll(RegExp(r'[\s\-]'), '');
    final validIdentifier = _emailPattern.hasMatch(trimmedId) ||
        _phoneDigitsPattern.hasMatch(compactPhone);

    if (!validIdentifier) {
      throw const InvalidIdentifierFailure();
    }
    if (password.length < 8) {
      throw const WeakPasswordFailure();
    }

    final session = await authGateway.login(
      identifier: trimmedId,
      password: password,
      deviceId: deviceId,
    );

    final updated = current.copyWith(
      authMode: OnboardingAuthMode.account,
      displayName: session.displayName,
      role: session.role,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    await repository.saveStatus(updated);
    return updated;
  }
}
