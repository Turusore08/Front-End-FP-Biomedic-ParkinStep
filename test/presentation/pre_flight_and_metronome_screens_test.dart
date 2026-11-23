import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/application/ports/cueing_port.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/di/session_prep_providers.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/metronome/screens/metronome_ras_screen.dart';
import 'package:parkinstep/presentation/features/session_prep/screens/pre_flight_checklist_screen.dart';
import 'package:parkinstep/presentation/features/session_prep/screens/test_selection_screen.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopCueingPort implements CueingPort {
  int beatCalls = 0;
  bool? lastSoundFlag;

  @override
  Future<void> playMetronomeBeat({
    required bool accented,
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    beatCalls++;
    lastSoundFlag = soundEnabled;
  }

  @override
  Future<void> playCompletionChime({
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {}
}

Future<SharedPreferences> _seedCompletedPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await LocalOnboardingRepository(prefs).saveStatus(
    OnboardingStatus(
      authMode: OnboardingAuthMode.account,
      displayName: 'Pak Budi',
      updatedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
      consent: ConsentPreferences(
        consentLocal: true,
        consentSkeletonSync: false,
        consentCloudVideo: false,
        acceptedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
      ),
    ),
  );
  return prefs;
}

Widget _wrapApp(SharedPreferences prefs, {CueingPort? cueingPort}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (cueingPort != null) cueingPortProvider.overrideWithValue(cueingPort),
    ],
    child: const ParkinStepApp(),
  );
}

Future<void> _pumpA11yViewport(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required Widget child,
  CueingPort? cueingPort,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (cueingPort != null) cueingPortProvider.overrideWithValue(cueingPort),
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

  group('Test Selection, S-04 Pre-Flight Safety Checklist & S-07 RAS Metronome Verification', () {
    testWidgets(
        'S-03 Mulai Tes opens 3-test picker -> selects Jalan Bolak-Balik -> S-04 enforces 4/4 checks -> navigates to readyToRecord & cancels cleanly',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _NoopCueingPort();
      await tester.pumpWidget(_wrapApp(prefs, cueingPort: cueing));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_card_tes_360')));
      await tester.pumpAndSettle();

      // Verify all 3 protocol cards are visible
      expect(find.text('Pilih Jenis Tes'), findsOneWidget);
      expect(find.byKey(const Key('test_card_turning360')), findsOneWidget);
      expect(
        find.byKey(const Key('test_card_walkBackAndForth')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('test_card_sitToStand')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('test_card_walkBackAndForth')),
      );
      await tester.tap(find.byKey(const Key('test_card_walkBackAndForth')));
      await tester.pumpAndSettle();

      expect(find.text('Keselamatan Sebelum Tes'), findsOneWidget);
      expect(find.text('Tes Berjalan Bolak-Balik · 2 Menit'), findsOneWidget);
      expect(find.text('Jalur Lurus Bebas 3 m'), findsOneWidget);
      expect(find.text('Lanjut ke Kamera (0/4)'), findsOneWidget);

      // Disabled at 0/4 does not navigate to camera screen
      await tester.ensureVisible(
        find.byKey(const Key('preflight_continue_button')),
      );
      await tester.tap(find.byKey(const Key('preflight_continue_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live_cancel_button')), findsNothing);

      // Check all 4 mandatory physical safety tiles
      for (final key in const <Key>[
        Key('checklist_floor_tile'),
        Key('checklist_space_tile'),
        Key('checklist_support_tile'),
        Key('checklist_attire_tile'),
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pump();
      }

      await tester.ensureVisible(find.byKey(const Key('preflight_med_on')));
      await tester.tap(find.byKey(const Key('preflight_med_on')));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut ke Kamera (4/4)'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('preflight_continue_button')),
      );
      await tester.tap(find.byKey(const Key('preflight_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('live_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('record_ready_card')), findsOneWidget);
      expect(find.byKey(const Key('record_start_button')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('live_cancel_button')));
      await tester.tap(find.byKey(const Key('live_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Keselamatan Sebelum Tes'), findsOneWidget);
    });

    testWidgets(
        'S-03 Cueing RAS opens S-07, steps diamond BPM, switches presets, toggles sound, starts/stops & resets cleanly',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _NoopCueingPort();
      await tester.pumpWidget(_wrapApp(prefs, cueingPort: cueing));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_card_cueing_ras')));
      await tester.pumpAndSettle();

      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);

      // Diamond up (+5 BPM -> 85 BPM, 170 steps)
      await tester.tap(find.byKey(const Key('metronome_bpm_up')));
      await tester.pump();
      expect(find.text('85'), findsOneWidget);
      expect(find.text('170'), findsOneWidget);

      // Diamond down (-5 BPM -> 80 BPM, 160 steps)
      await tester.tap(find.byKey(const Key('metronome_bpm_down')));
      await tester.pump();
      expect(find.text('80'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);

      // Duration preset -> 1 Mnt (01:00, 80 steps)
      await tester.ensureVisible(find.byKey(const Key('metronome_dur_60')));
      await tester.tap(find.byKey(const Key('metronome_dur_60')));
      await tester.pump();
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('80'), findsWidgets);

      // Toggle mute sound before starting
      await tester.ensureVisible(
        find.byKey(const Key('metronome_sound_toggle_button')),
      );
      await tester.tap(find.byKey(const Key('metronome_sound_toggle_button')));
      await tester.pump();

      // Start metronome, allow beat pulse to settle, stop & reset
      await tester.ensureVisible(find.byKey(const Key('metronome_toggle_button')));
      await tester.tap(find.byKey(const Key('metronome_toggle_button')));
      await tester.pump(const Duration(milliseconds: 160));

      expect(find.text('Hentikan Metronom'), findsOneWidget);
      expect(cueing.beatCalls, greaterThanOrEqualTo(1));
      expect(cueing.lastSoundFlag, isFalse);

      await tester.tap(find.byKey(const Key('metronome_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('Mulai Metronom'), findsOneWidget);
      expect(find.byKey(const Key('metronome_reset_button')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('metronome_reset_button')));
      await tester.tap(find.byKey(const Key('metronome_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('01:00'), findsOneWidget);
      expect(find.byKey(const Key('metronome_reset_button')), findsNothing);
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: TestSelectionScreen renders zero overflow & >= 56/96dp touch targets',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      await _pumpA11yViewport(
        tester,
        prefs: prefs,
        child: const TestSelectionScreen(),
      );

      expect(
        tester.getSize(find.byKey(const Key('select_test_back_button'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('select_test_voice_button'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('test_card_turning360'))).height,
        greaterThanOrEqualTo(96.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('test_card_walkBackAndForth'))).height,
        greaterThanOrEqualTo(96.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('test_card_sitToStand'))).height,
        greaterThanOrEqualTo(96.0),
      );
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: S-04 PreFlightChecklistScreen renders zero overflow & >= 56/64dp touch targets',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      await _pumpA11yViewport(
        tester,
        prefs: prefs,
        child: const PreFlightChecklistScreen(),
      );

      final backSize = tester.getSize(
        find.byKey(const Key('preflight_back_button')),
      );
      final floorSize = tester.getSize(
        find.byKey(const Key('checklist_floor_tile')),
      );
      final spaceSize = tester.getSize(
        find.byKey(const Key('checklist_space_tile')),
      );
      final supportSize = tester.getSize(
        find.byKey(const Key('checklist_support_tile')),
      );
      final attireSize = tester.getSize(
        find.byKey(const Key('checklist_attire_tile')),
      );
      final medOnSize = tester.getSize(find.byKey(const Key('preflight_med_on')));
      final ctaSize = tester.getSize(
        find.byKey(const Key('preflight_continue_button')),
      );

      expect(backSize.height, greaterThanOrEqualTo(56.0));
      expect(floorSize.height, greaterThanOrEqualTo(64.0));
      expect(spaceSize.height, greaterThanOrEqualTo(64.0));
      expect(supportSize.height, greaterThanOrEqualTo(64.0));
      expect(attireSize.height, greaterThanOrEqualTo(64.0));
      expect(medOnSize.height, greaterThanOrEqualTo(56.0));
      expect(ctaSize.height, greaterThanOrEqualTo(64.0));
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: S-07 MetronomeRasScreen renders zero overflow & 64x64 diamond steppers',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _NoopCueingPort();
      await _pumpA11yViewport(
        tester,
        prefs: prefs,
        cueingPort: cueing,
        child: const MetronomeRasScreen(),
      );

      final backSize = tester.getSize(
        find.byKey(const Key('metronome_back_button')),
      );
      final helpSize = tester.getSize(
        find.byKey(const Key('metronome_help_button')),
      );
      final soundSize = tester.getSize(
        find.byKey(const Key('metronome_sound_toggle_button')),
      );
      final downSize = tester.getSize(
        find.byKey(const Key('metronome_bpm_down')),
      );
      final upSize = tester.getSize(
        find.byKey(const Key('metronome_bpm_up')),
      );
      final dur60Size = tester.getSize(find.byKey(const Key('metronome_dur_60')));
      final toggleSize = tester.getSize(
        find.byKey(const Key('metronome_toggle_button')),
      );

      expect(backSize.height, greaterThanOrEqualTo(56.0));
      expect(helpSize.width, greaterThanOrEqualTo(56.0));
      expect(helpSize.height, greaterThanOrEqualTo(56.0));
      expect(soundSize.width, greaterThanOrEqualTo(56.0));
      expect(soundSize.height, greaterThanOrEqualTo(56.0));
      expect(downSize.width, greaterThanOrEqualTo(64.0));
      expect(downSize.height, greaterThanOrEqualTo(64.0));
      expect(upSize.width, greaterThanOrEqualTo(64.0));
      expect(upSize.height, greaterThanOrEqualTo(64.0));
      expect(dur60Size.height, greaterThanOrEqualTo(56.0));
      expect(toggleSize.height, greaterThanOrEqualTo(64.0));
    });
  });
}
