import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/domain/enums/user_role.dart';

void main() {
  group('Domain entities & UU PDP consent invariants', () {
    test('default ConsentPreferences enables only local processing', () {
      const prefs = ConsentPreferences();
      expect(prefs.consentLocal, isTrue);
      expect(prefs.consentSkeletonSync, isFalse);
      expect(prefs.consentCloudVideo, isFalse);
      expect(prefs.canProceed, isTrue);
    });

    test('canProceed becomes false when mandatory consentLocal is turned off', () {
      final prefs = const ConsentPreferences().copyWith(consentLocal: false);
      expect(prefs.canProceed, isFalse);
    });

    test('OnboardingStatus.isCompleted requires authMode, consentLocal, and UTC timestamp', () {
      const initial = OnboardingStatus();
      expect(initial.isCompleted, isFalse);

      final authOnly = initial.copyWith(authMode: OnboardingAuthMode.offlineLocal);
      expect(authOnly.isCompleted, isFalse);

      final complete = authOnly.copyWith(
        consent: ConsentPreferences(
          consentLocal: true,
          acceptedAtUtc: DateTime.utc(2026, 11, 20, 12, 0),
        ),
      );
      expect(complete.isCompleted, isTrue);

      final revokedLocal = complete.copyWith(
        consent: complete.consent.copyWith(consentLocal: false),
      );
      expect(revokedLocal.isCompleted, isFalse);
    });

    test('wire enums round-trip cleanly and fallback safely', () {
      expect(
        OnboardingAuthMode.fromWire('ACCOUNT'),
        OnboardingAuthMode.account,
      );
      expect(
        OnboardingAuthMode.fromWire('OFFLINE_LOCAL'),
        OnboardingAuthMode.offlineLocal,
      );
      expect(OnboardingAuthMode.fromWire('UNKNOWN'), isNull);
      expect(UserRole.fromWire('CLINICIAN'), UserRole.clinician);
      expect(UserRole.fromWire('BAD_VALUE'), UserRole.patient);
    });

    test('ClinicalCopy contains verbatim Medical Disclaimer without em dashes', () {
      expect(ClinicalCopy.medicalDisclaimer, contains('PERHATIAN MEDIS:'));
      expect(ClinicalCopy.medicalDisclaimer, contains('BUKAN merupakan diagnosis medis resmi'));
      expect(ClinicalCopy.medicalDisclaimer.contains('\u2014'), isFalse);
    });
  });
}
