import '../../domain/enums/user_role.dart';

/// Result of authenticating an existing ParkinStep account.
class AuthSessionResult {
  const AuthSessionResult({
    required this.patientId,
    required this.displayName,
    required this.role,
    required this.isLocalPreviewSession,
  });

  final String patientId;
  final String displayName;
  final UserRole role;

  /// Explicitly indicates when session was created in offline/preview mode
  /// without an active companion backend server.
  final bool isLocalPreviewSession;
}

/// Port wrapping `POST /api/v1/auth/login` from docs/API_CONTRACT.md.
abstract interface class AuthGatewayPort {
  Future<AuthSessionResult> login({
    required String identifier,
    required String password,
    required String deviceId,
  });
}
