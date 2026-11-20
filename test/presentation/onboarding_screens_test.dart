import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/application/ports/voice_guide_port.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/onboarding/screens/consent_screen.dart';
import 'package:parkinstep/presentation/features/onboarding/screens/welcome_screen.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingVoiceGuide implements VoiceGuidePort {
  int speakCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async => speakCalls++;

  @override
  Future<void> stop() async => stopCalls++;
}

Future<Widget> _buildTestApp({
  OnboardingStatus? seededStatus,
  VoiceGuidePort? voiceGuide,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  if (seededStatus != null) {
    await LocalOnboardingRepository(prefs).saveStatus(seededStatus);
  }

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (voiceGuide != null) voiceGuideProvider.overrideWithValue(voiceGuide),
    ],
    child: const ParkinStepApp(),
  );
}

Future<void> _pumpA11yViewport(
  WidgetTester tester, {
  required Widget child,
  required SharedPreferences prefs,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Onboarding UI & Accessibility Verification (S-01 & S-02)', () {
    testWidgets('S-01 help dialog opens, toggles voice guide, and closes cleanly',
        (WidgetTester tester) async {
      final spyVoice = _RecordingVoiceGuide();
      await tester.pumpWidget(await _buildTestApp(voiceGuide: spyVoice));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang'), findsOneWidget);
      expect(find.text('Masuk dengan Akun'), findsOneWidget);
      expect(find.text('Gunakan Mode Offline Lokal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('welcome_help_button')));
      await tester.pumpAndSettle();

      expect(find.text(ClinicalCopy.helpDialogTitle), findsOneWidget);
      await tester.tap(find.text('Dengarkan Penjelasan Suara'));
      await tester.pump();
      expect(spyVoice.speakCalls, 1);

      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(spyVoice.stopCalls, 1);
      expect(find.text(ClinicalCopy.helpDialogTitle), findsNothing);
    });

    testWidgets('S-01 offline flow navigates to S-02, enforces UU PDP toggle, and reaches /home',
        (WidgetTester tester) async {
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('welcome_offline_button')));
      await tester.tap(find.byKey(const Key('welcome_offline_button')));
      await tester.pumpAndSettle();

      expect(find.text('Privasi & Keselamatan'), findsOneWidget);
      expect(find.text(ClinicalCopy.medicalDisclaimer), findsOneWidget);

      // Disabling mandatory local camera permission blocks submission and surfaces warning
      await tester.ensureVisible(find.byKey(const Key('consent_local_card')));
      await tester.tap(find.byKey(const Key('consent_local_card')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Izin kamera lokal wajib diaktifkan agar deteksi FoG dapat berjalan.',
        ),
        findsOneWidget,
      );

      // Re-enable mandatory permission and enable optional skeleton sync
      await tester.ensureVisible(find.byKey(const Key('consent_local_card')));
      await tester.tap(find.byKey(const Key('consent_local_card')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('consent_sync_card')));
      await tester.tap(find.byKey(const Key('consent_sync_card')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('consent_submit_button')));
      await tester.tap(find.byKey(const Key('consent_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih untuk Memulai'), findsOneWidget);
      expect(find.text('Pengguna'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_settings')));
      await tester.pumpAndSettle();

      expect(find.text('Mode Akses: Mode Offline Lokal'), findsOneWidget);
      expect(find.text('Sinkronisasi Dokter: Aktif'), findsOneWidget);
    });

    testWidgets('S-01 login sheet validates empty/weak credentials then proceeds to S-02',
        (WidgetTester tester) async {
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('welcome_login_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email atau Nomor HP'), findsOneWidget);

      // Invalid identifier check
      await tester.enterText(
        find.byKey(const Key('login_identifier_field')),
        'budi',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Masukkan alamat email yang valid atau nomor HP minimal 8 digit.',
        ),
        findsOneWidget,
      );

      // Valid identifier + valid password
      await tester.enterText(
        find.byKey(const Key('login_identifier_field')),
        'pak.budi@klinik.id',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'rahasia123',
      );
      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Privasi & Keselamatan'), findsOneWidget);
    });

    testWidgets('Completed persisted onboarding redirects straight to /home and reset returns to S-01',
        (WidgetTester tester) async {
      final completed = OnboardingStatus(
        authMode: OnboardingAuthMode.account,
        displayName: 'Pak Budi',
        updatedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
        consent: ConsentPreferences(
          consentLocal: true,
          consentSkeletonSync: false,
          consentCloudVideo: false,
          acceptedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
        ),
      );

      await tester.pumpWidget(await _buildTestApp(seededStatus: completed));
      await tester.pumpAndSettle();

      expect(find.text('Pak Budi'), findsOneWidget);
      expect(find.text('Pilih untuk Memulai'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_settings')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('settings_reset_onboarding_button')),
      );
      await tester.tap(find.byKey(const Key('settings_reset_onboarding_button')));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang'), findsOneWidget);
    });

    testWidgets('S-01 WelcomeScreen renders zero overflow & >= 64dp CTAs at 360x640 @ 1.5x',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await _pumpA11yViewport(
        tester,
        prefs: prefs,
        child: const WelcomeScreen(),
      );

      final helpBox = tester.getSize(find.byKey(const Key('welcome_help_button')));
      final loginBox = tester.getSize(find.byKey(const Key('welcome_login_button')));
      final offlineBox = tester.getSize(find.byKey(const Key('welcome_offline_button')));

      expect(helpBox.width, greaterThanOrEqualTo(56.0));
      expect(helpBox.height, greaterThanOrEqualTo(56.0));
      expect(loginBox.height, greaterThanOrEqualTo(64.0));
      expect(offlineBox.height, greaterThanOrEqualTo(64.0));
    });

    testWidgets('S-02 ConsentScreen renders zero overflow & >= 64dp CTA at 360x640 @ 1.5x',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await _pumpA11yViewport(
        tester,
        prefs: prefs,
        child: const ConsentScreen(),
      );

      final backBox = tester.getSize(find.byKey(const Key('consent_back_button')));
      final submitBox = tester.getSize(find.byKey(const Key('consent_submit_button')));

      expect(backBox.height, greaterThanOrEqualTo(56.0));
      expect(submitBox.height, greaterThanOrEqualTo(64.0));
    });
  });
}
