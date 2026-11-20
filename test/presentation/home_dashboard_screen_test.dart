import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/di/dashboard_providers.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/entities/session_summary_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/infrastructure/persistence/local_home_dashboard_repository.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/home/screens/home_dashboard_screen.dart';
import 'package:parkinstep/presentation/widgets/design_system/parkin_bottom_nav.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _seedCompletedAppPrefs({
  List<SessionSummaryItem> sessions = const <SessionSummaryItem>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await LocalOnboardingRepository(prefs).saveStatus(
    OnboardingStatus(
      authMode: OnboardingAuthMode.account,
      displayName: 'Pak Budi',
      updatedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
      consent: ConsentPreferences(
        consentLocal: true,
        consentSkeletonSync: true,
        consentCloudVideo: false,
        acceptedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
      ),
    ),
  );
  final dashboardRepo = LocalHomeDashboardRepository(prefs);
  for (final s in sessions) {
    await dashboardRepo.saveSessionSummary(s);
  }
  return prefs;
}

Widget _wrapWithApp(
  SharedPreferences prefs, {
  DateTime? fixedClock,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (fixedClock != null)
        homeDashboardClockProvider.overrideWithValue(() => fixedClock),
    ],
    child: const ParkinStepApp(),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('S-03 Beranda Dashboard & 4-Tab Navigation Verification', () {
    testWidgets(
        'Fresh completed user sees S-03 greeting, 3 cards, empty MetricPill, reminder & State/EmptyHistory',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs();
      final fixedMorning = DateTime(2026, 11, 20, 8, 30);

      await tester.pumpWidget(_wrapWithApp(prefs, fixedClock: fixedMorning));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Pagi,'), findsOneWidget);
      expect(find.text('Pak Budi'), findsOneWidget);
      expect(find.text('Pilih untuk Memulai'), findsOneWidget);
      expect(find.text('Tes 360°'), findsOneWidget);
      expect(find.text('Cueing RAS'), findsOneWidget);
      expect(find.text('Catat Obat'), findsOneWidget);
      expect(find.text('Belum Ada Tes'), findsOneWidget);
      expect(find.byKey(const Key('home_reminder_card')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_history_state')), findsOneWidget);
      expect(find.text('Belum ada riwayat sesi'), findsOneWidget);
      expect(find.text('BERANDA'), findsOneWidget);
      expect(find.text('RIWAYAT'), findsOneWidget);
      expect(find.text('BANTUAN'), findsOneWidget);
      expect(find.text('PENGATURAN'), findsOneWidget);
    });

    testWidgets('Tapping Lewati dismisses daily reminder and persists across rebuilds',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs();
      final fixedMorning = DateTime(2026, 11, 20, 9, 0);

      await tester.pumpWidget(_wrapWithApp(prefs, fixedClock: fixedMorning));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_reminder_card')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('reminder_dismiss_button')));
      await tester.tap(find.byKey(const Key('reminder_dismiss_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_reminder_card')), findsNothing);

      // Rebuild fresh widget tree from same SharedPreferences
      await tester.pumpWidget(
        _wrapWithApp(prefs, fixedClock: fixedMorning),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_reminder_card')), findsNothing);
    });

    testWidgets(
        'Catat Obat sheet logs ON Levodopa 150 mg, updates MetricPill, and displays in Riwayat tab',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs();
      await tester.pumpWidget(_wrapWithApp(prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_card_catat_obat')));
      await tester.pumpAndSettle();

      expect(find.text('Catat Obat Levodopa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('med_state_on')));
      await tester.pump();
      await tester.tap(find.text('150 mg'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('med_submit_button')));
      await tester.tap(find.byKey(const Key('med_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Catat Obat Levodopa'), findsNothing);
      expect(find.text('ON Obat'), findsWidgets);
      expect(find.text('Tercatat'), findsOneWidget);

      // Navigate to RIWAYAT tab and confirm entry appears
      await tester.tap(find.byKey(const Key('nav_tab_history')));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat & Tren Obat'), findsOneWidget);
      expect(find.text('Levodopa / Carbidopa (150 mg)'), findsOneWidget);
    });

    testWidgets(
        'Seeded sessions render tabular FoG metric and horizontal carousel instead of empty state',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs(
        sessions: <SessionSummaryItem>[
          SessionSummaryItem(
            sessionId: 'sess-1',
            startedAtUtc: DateTime.utc(2026, 11, 20, 7, 30),
            medState: MedicationState.on,
            fogPercentage: 2.4,
            episodeCount: 0,
            durationSec: 120.0,
          ),
          SessionSummaryItem(
            sessionId: 'sess-2',
            startedAtUtc: DateTime.utc(2026, 11, 19, 7, 30),
            medState: MedicationState.off,
            fogPercentage: 18.5,
            episodeCount: 2,
            durationSec: 120.0,
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithApp(prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_empty_history_state')), findsNothing);
      expect(find.text('2,4% FoG'), findsOneWidget);
      expect(find.text('2,4%'), findsOneWidget);
      expect(find.text('18,5%'), findsOneWidget);
    });

    testWidgets(
        'Privacy Shield opens modal and 4-tab bottom nav switches cleanly across all tabs',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs();
      await tester.pumpWidget(_wrapWithApp(prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_privacy_shield_button')));
      await tester.pumpAndSettle();
      expect(find.text(ClinicalCopy.privacyShieldTitle), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('shield_open_settings_button')),
      );
      await tester.tap(find.byKey(const Key('shield_open_settings_button')));
      await tester.pumpAndSettle();
      expect(find.text('Pengaturan & Privasi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_help')));
      await tester.pumpAndSettle();
      expect(find.text('Panduan Penggunaan'), findsOneWidget);
      expect(find.text(ClinicalCopy.medicalDisclaimer), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_history')));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat & Tren Obat'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_home')));
      await tester.pumpAndSettle();
      expect(find.text('Pilih untuk Memulai'), findsOneWidget);
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: S-03 & ParkinBottomNav render zero overflow with compliant touch targets',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedAppPrefs();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeDashboardClockProvider.overrideWithValue(
              () => DateTime(2026, 11, 20, 8, 30),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: Scaffold(
                body: const HomeDashboardScreen(),
                bottomNavigationBar: ParkinBottomNav(
                  currentIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final shieldSize = tester.getSize(
        find.byKey(const Key('home_privacy_shield_button')),
      );
      final tesCardSize = tester.getSize(
        find.byKey(const Key('home_card_tes_360')),
      );
      final rasCardSize = tester.getSize(
        find.byKey(const Key('home_card_cueing_ras')),
      );
      final medCardSize = tester.getSize(
        find.byKey(const Key('home_card_catat_obat')),
      );
      final dismissSize = tester.getSize(
        find.byKey(const Key('reminder_dismiss_button')),
      );
      final startSize = tester.getSize(
        find.byKey(const Key('reminder_start_button')),
      );
      final emptyCtaSize = tester.getSize(
        find.byKey(const Key('empty_start_first_test_button')),
      );
      final navBarSize = tester.getSize(find.byType(ParkinBottomNav));
      final navSettingsSize = tester.getSize(
        find.byKey(const Key('nav_tab_settings')),
      );

      expect(shieldSize.width, greaterThanOrEqualTo(56.0));
      expect(shieldSize.height, greaterThanOrEqualTo(56.0));
      expect(tesCardSize.height, greaterThanOrEqualTo(158.0));
      expect(rasCardSize.height, greaterThanOrEqualTo(158.0));
      expect(medCardSize.height, greaterThanOrEqualTo(158.0));
      expect(dismissSize.height, greaterThanOrEqualTo(56.0));
      expect(startSize.height, greaterThanOrEqualTo(56.0));
      expect(emptyCtaSize.height, greaterThanOrEqualTo(64.0));
      expect(navBarSize.height, greaterThanOrEqualTo(72.0));
      expect(navSettingsSize.height, greaterThanOrEqualTo(56.0));
    });
  });
}
