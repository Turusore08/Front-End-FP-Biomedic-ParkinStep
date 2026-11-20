import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/controllers/onboarding_coordinator.dart';
import '../application/controllers/onboarding_ui_state.dart';
import '../application/ports/auth_gateway_port.dart';
import '../application/ports/onboarding_repository_port.dart';
import '../application/ports/voice_guide_port.dart';
import '../infrastructure/cueing/noop_voice_guide_adapter.dart';
import '../infrastructure/network/local_preview_auth_gateway.dart';
import '../infrastructure/persistence/local_onboarding_repository.dart';

/// Must be overridden inside root ProviderScope after SharedPreferences.getInstance().
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final onboardingRepositoryProvider = Provider<OnboardingRepositoryPort>(
  (ref) => LocalOnboardingRepository(ref.watch(sharedPreferencesProvider)),
);

final authGatewayProvider = Provider<AuthGatewayPort>(
  (ref) => const LocalPreviewAuthGateway(),
);

final voiceGuideProvider = Provider<VoiceGuidePort>(
  (ref) => const NoopVoiceGuideAdapter(),
);

/// Riverpod 3 Notifier binding pure-Dart OnboardingCoordinator to Flutter UI.
class OnboardingController extends Notifier<OnboardingUiState> {
  late OnboardingCoordinator _coordinator;

  @override
  OnboardingUiState build() {
    _coordinator = OnboardingCoordinator(
      repository: ref.read(onboardingRepositoryProvider),
      authGateway: ref.read(authGatewayProvider),
      voiceGuide: ref.read(voiceGuideProvider),
      readState: () => state,
      writeState: (next) => state = next,
    );

    Future<void>.microtask(_coordinator.initialize);
    return const OnboardingUiState();
  }

  Future<void> initialize() => _coordinator.initialize();

  Future<bool> continueOffline() => _coordinator.continueOffline();

  Future<String?> signInWithAccount({
    required String identifier,
    required String password,
  }) =>
      _coordinator.signInWithAccount(
        identifier: identifier,
        password: password,
      );

  void setConsentLocal(bool value) => _coordinator.setConsentLocal(value);

  void setConsentSkeletonSync(bool value) =>
      _coordinator.setConsentSkeletonSync(value);

  void setConsentCloudVideo(bool value) =>
      _coordinator.setConsentCloudVideo(value);

  Future<bool> submitConsent() => _coordinator.submitConsent();

  Future<void> toggleVoiceGuide(String text) =>
      _coordinator.toggleVoiceGuide(text);

  Future<void> stopVoiceGuide() => _coordinator.stopVoiceGuide();

  Future<void> resetOnboarding() => _coordinator.resetOnboarding();
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingUiState>(
  OnboardingController.new,
);
