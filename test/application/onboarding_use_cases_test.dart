import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/application/controllers/onboarding_coordinator.dart';
import 'package:parkinstep/application/controllers/onboarding_ui_state.dart';
import 'package:parkinstep/application/ports/auth_gateway_port.dart';
import 'package:parkinstep/application/ports/onboarding_repository_port.dart';
import 'package:parkinstep/application/ports/voice_guide_port.dart';
import 'package:parkinstep/application/use_cases/continue_offline_local.dart';
import 'package:parkinstep/application/use_cases/sign_in_with_account.dart';
import 'package:parkinstep/application/use_cases/submit_uupdp_consent.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/domain/enums/user_role.dart';
import 'package:parkinstep/domain/errors/onboarding_failure.dart';
import 'package:parkinstep/infrastructure/network/local_preview_auth_gateway.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryOnboardingRepository implements OnboardingRepositoryPort {
  OnboardingStatus _stored = const OnboardingStatus();

  @override
  Future<void> clearStatus() async {
    _stored = const OnboardingStatus();
  }

  @override
  Future<OnboardingStatus> loadStatus() async => _stored;

  @override
  Future<void> saveStatus(OnboardingStatus status) async {
    _stored = status;
  }
}

class _SpyVoiceGuide implements VoiceGuidePort {
  int speakCount = 0;
  int stopCount = 0;
  String? lastSpoken;

  @override
  Future<void> speak(String text) async {
    speakCount++;
    lastSpoken = text;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

void main() {
  group('Application onboarding use cases & persistence', () {
    test('ContinueOfflineLocal sets OFFLINE_LOCAL mode and UTC timestamp', () async {
      final repo = _InMemoryOnboardingRepository();
      final useCase = ContinueOfflineLocal(repo);

      final result = await useCase.execute(const OnboardingStatus());

      expect(result.authMode, OnboardingAuthMode.offlineLocal);
      expect(result.updatedAtUtc?.isUtc, isTrue);
      expect((await repo.loadStatus()).authMode, OnboardingAuthMode.offlineLocal);
    });

    test('SignInWithAccount validates identifier and password before calling gateway', () async {
      final repo = _InMemoryOnboardingRepository();
      const gateway = LocalPreviewAuthGateway();
      final useCase = SignInWithAccount(authGateway: gateway, repository: repo);

      await expectLater(
        () => useCase.execute(
          current: const OnboardingStatus(),
          identifier: 'abc',
          password: 'password123',
          deviceId: 'dev-1',
        ),
        throwsA(isA<InvalidIdentifierFailure>()),
      );

      await expectLater(
        () => useCase.execute(
          current: const OnboardingStatus(),
          identifier: '08123456789',
          password: 'short',
          deviceId: 'dev-1',
        ),
        throwsA(isA<WeakPasswordFailure>()),
      );

      final ok = await useCase.execute(
        current: const OnboardingStatus(),
        identifier: 'pakbudi@klinik.id',
        password: 'password123',
        deviceId: 'dev-1',
      );
      expect(ok.authMode, OnboardingAuthMode.account);
      expect(ok.displayName, 'Pakbudi');
    });

    test('SubmitUupdpConsent blocks when mandatory local consent is false', () async {
      final repo = _InMemoryOnboardingRepository();
      final useCase = SubmitUupdpConsent(repo);

      await expectLater(
        () => useCase.execute(
          current: const OnboardingStatus(authMode: OnboardingAuthMode.offlineLocal),
          consent: const ConsentPreferences(consentLocal: false),
        ),
        throwsA(isA<LocalConsentRequiredFailure>()),
      );
    });

    test('OnboardingCoordinator manages voice guide and consent submission end-to-end', () async {
      final repo = _InMemoryOnboardingRepository();
      final voice = _SpyVoiceGuide();
      var state = const OnboardingUiState();
      final coordinator = OnboardingCoordinator(
        repository: repo,
        authGateway: const LocalPreviewAuthGateway(),
        voiceGuide: voice,
        readState: () => state,
        writeState: (next) => state = next,
      );

      await coordinator.initialize();
      expect(state.isInitialized, isTrue);

      await coordinator.toggleVoiceGuide('Panduan awal');
      expect(state.isSpeakingGuide, isTrue);
      expect(voice.speakCount, 1);

      await coordinator.stopVoiceGuide();
      expect(state.isSpeakingGuide, isFalse);
      expect(voice.stopCount, 1);

      expect(await coordinator.continueOffline(), isTrue);
      coordinator.setConsentSkeletonSync(true);
      expect(await coordinator.submitConsent(), isTrue);

      expect(state.status.isCompleted, isTrue);
      expect(state.status.consent.consentSkeletonSync, isTrue);
      expect(state.status.consent.acceptedAtUtc?.isUtc, isTrue);
    });

    test('LocalOnboardingRepository persists UTC timestamps & String Enums cleanly', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalOnboardingRepository(prefs);

      final saved = OnboardingStatus(
        authMode: OnboardingAuthMode.account,
        displayName: 'Bu Sari',
        role: UserRole.caregiver,
        updatedAtUtc: DateTime.utc(2026, 11, 20, 10, 30),
        consent: ConsentPreferences(
          consentLocal: true,
          consentSkeletonSync: true,
          consentCloudVideo: false,
          acceptedAtUtc: DateTime.utc(2026, 11, 20, 10, 31),
        ),
      );

      await repo.saveStatus(saved);
      final reloaded = await repo.loadStatus();

      expect(reloaded, saved);
      expect(reloaded.isCompleted, isTrue);
    });

    test('AuthSessionResult holds explicit preview marker', () {
      const res = AuthSessionResult(
        patientId: 'p-1',
        displayName: 'Pak Budi',
        role: UserRole.patient,
        isLocalPreviewSession: true,
      );
      expect(res.isLocalPreviewSession, isTrue);
    });
  });
}
