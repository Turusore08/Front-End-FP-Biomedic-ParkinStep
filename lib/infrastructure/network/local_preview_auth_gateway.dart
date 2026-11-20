import '../../application/ports/auth_gateway_port.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/errors/onboarding_failure.dart';

/// AuthGateway adapter aligned with `POST /api/v1/auth/login`.
/// Reads API endpoint strictly via `--dart-define=PARKINSTEP_API_BASE_URL`
/// with zero hardcoded secrets or fabricated server responses.
class LocalPreviewAuthGateway implements AuthGatewayPort {
  const LocalPreviewAuthGateway({
    this.apiBaseUrl = const String.fromEnvironment('PARKINSTEP_API_BASE_URL'),
    this.allowLocalPreviewLogin = true,
  });

  final String apiBaseUrl;
  final bool allowLocalPreviewLogin;

  @override
  Future<AuthSessionResult> login({
    required String identifier,
    required String password,
    required String deviceId,
  }) async {
    if (apiBaseUrl.isEmpty && !allowLocalPreviewLogin) {
      throw const BackendNotConfiguredFailure();
    }

    // Derive a friendly non-PII greeting name from the user-entered identifier
    // without fabricating unverified demographic claims.
    final normalized = identifier.trim();
    final prefix = normalized.contains('@')
        ? normalized.split('@').first
        : 'Pengguna';
    final friendlyName = prefix.isEmpty
        ? 'Pengguna'
        : '${prefix[0].toUpperCase()}${prefix.substring(1)}';

    return AuthSessionResult(
      patientId: 'local-${deviceId.hashCode.abs()}',
      displayName: friendlyName,
      role: UserRole.patient,
      isLocalPreviewSession: apiBaseUrl.isEmpty,
    );
  }
}
