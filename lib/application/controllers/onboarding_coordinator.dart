import '../../domain/entities/consent_preferences.dart';
import '../../domain/entities/onboarding_status.dart';
import '../../domain/errors/onboarding_failure.dart';
import '../ports/auth_gateway_port.dart';
import '../ports/onboarding_repository_port.dart';
import '../ports/voice_guide_port.dart';
import '../use_cases/continue_offline_local.dart';
import '../use_cases/sign_in_with_account.dart';
import '../use_cases/submit_uupdp_consent.dart';
import 'onboarding_ui_state.dart';

/// Pure Dart coordinator orchestrating S-01 & S-02 state transitions without
/// coupling application logic to Flutter widgets or third-party packages.
class OnboardingCoordinator {
  OnboardingCoordinator({
    required OnboardingRepositoryPort repository,
    required AuthGatewayPort authGateway,
    required this.voiceGuide,
    required this.readState,
    required this.writeState,
  })  : _repository = repository,
        _continueOfflineLocal = ContinueOfflineLocal(repository),
        _signInWithAccount = SignInWithAccount(
          authGateway: authGateway,
          repository: repository,
        ),
        _submitUupdpConsent = SubmitUupdpConsent(repository);

  final OnboardingRepositoryPort _repository;
  final VoiceGuidePort voiceGuide;
  final ContinueOfflineLocal _continueOfflineLocal;
  final SignInWithAccount _signInWithAccount;
  final SubmitUupdpConsent _submitUupdpConsent;

  final OnboardingUiState Function() readState;
  final void Function(OnboardingUiState next) writeState;

  Future<void> initialize() async {
    try {
      final loaded = await _repository.loadStatus();
      writeState(
        readState().copyWith(
          isInitialized: true,
          status: loaded,
          draftConsent: loaded.consent,
          clearError: true,
        ),
      );
    } on OnboardingFailure catch (e) {
      writeState(
        readState().copyWith(
          isInitialized: true,
          errorMessage: e.userMessageId,
        ),
      );
    } catch (_) {
      writeState(
        readState().copyWith(
          isInitialized: true,
          errorMessage:
              'Gagal membaca pengaturan lokal. Silakan lanjutkan ulang.',
        ),
      );
    }
  }

  Future<bool> continueOffline() async {
    writeState(readState().copyWith(isSubmitting: true, clearError: true));
    try {
      final nextStatus =
          await _continueOfflineLocal.execute(readState().status);
      writeState(
        readState().copyWith(
          isSubmitting: false,
          status: nextStatus,
          draftConsent: nextStatus.consent,
          isPreviewSession: false,
          clearError: true,
        ),
      );
      return true;
    } on OnboardingFailure catch (e) {
      writeState(
        readState().copyWith(isSubmitting: false, errorMessage: e.userMessageId),
      );
      return false;
    } catch (_) {
      writeState(
        readState().copyWith(
          isSubmitting: false,
          errorMessage:
              'Gagal mengaktifkan mode offline lokal. Silakan coba lagi.',
        ),
      );
      return false;
    }
  }

  Future<String?> signInWithAccount({
    required String identifier,
    required String password,
    String deviceId = 'local-mobile-device',
  }) async {
    writeState(readState().copyWith(isSubmitting: true, clearError: true));
    try {
      final nextStatus = await _signInWithAccount.execute(
        current: readState().status,
        identifier: identifier,
        password: password,
        deviceId: deviceId,
      );
      writeState(
        readState().copyWith(
          isSubmitting: false,
          status: nextStatus,
          draftConsent: nextStatus.consent,
          isPreviewSession: true,
          clearError: true,
        ),
      );
      return null;
    } on OnboardingFailure catch (e) {
      writeState(readState().copyWith(isSubmitting: false));
      return e.userMessageId;
    } catch (_) {
      const msg = 'Gagal memproses login. Silakan coba lagi.';
      writeState(readState().copyWith(isSubmitting: false));
      return msg;
    }
  }

  void setConsentLocal(bool value) {
    final nextConsent = readState().draftConsent.copyWith(consentLocal: value);
    writeState(
      readState().copyWith(
        draftConsent: nextConsent,
        clearError: true,
      ),
    );
  }

  void setConsentSkeletonSync(bool value) {
    final nextConsent =
        readState().draftConsent.copyWith(consentSkeletonSync: value);
    writeState(
      readState().copyWith(
        draftConsent: nextConsent,
        clearError: true,
      ),
    );
  }

  void setConsentCloudVideo(bool value) {
    final nextConsent =
        readState().draftConsent.copyWith(consentCloudVideo: value);
    writeState(
      readState().copyWith(
        draftConsent: nextConsent,
        clearError: true,
      ),
    );
  }

  Future<bool> submitConsent() async {
    writeState(readState().copyWith(isSubmitting: true, clearError: true));
    try {
      final nextStatus = await _submitUupdpConsent.execute(
        current: readState().status,
        consent: readState().draftConsent,
      );
      writeState(
        readState().copyWith(
          isSubmitting: false,
          status: nextStatus,
          draftConsent: nextStatus.consent,
          clearError: true,
        ),
      );
      return true;
    } on OnboardingFailure catch (e) {
      writeState(
        readState().copyWith(isSubmitting: false, errorMessage: e.userMessageId),
      );
      return false;
    } catch (_) {
      writeState(
        readState().copyWith(
          isSubmitting: false,
          errorMessage: 'Gagal menyimpan persetujuan UU PDP. Coba lagi.',
        ),
      );
      return false;
    }
  }

  Future<void> toggleVoiceGuide(String text) async {
    final currentlySpeaking = readState().isSpeakingGuide;
    if (currentlySpeaking) {
      await voiceGuide.stop();
      writeState(readState().copyWith(isSpeakingGuide: false));
      return;
    }
    writeState(readState().copyWith(isSpeakingGuide: true));
    await voiceGuide.speak(text);
  }

  Future<void> stopVoiceGuide() async {
    if (!readState().isSpeakingGuide) return;
    await voiceGuide.stop();
    writeState(readState().copyWith(isSpeakingGuide: false));
  }

  Future<void> resetOnboarding() async {
    await _repository.clearStatus();
    writeState(
      const OnboardingUiState(
        isInitialized: true,
        status: OnboardingStatus(),
        draftConsent: ConsentPreferences(),
      ),
    );
  }

  void clearError() {
    if (readState().errorMessage != null) {
      writeState(readState().copyWith(clearError: true));
    }
  }
}
