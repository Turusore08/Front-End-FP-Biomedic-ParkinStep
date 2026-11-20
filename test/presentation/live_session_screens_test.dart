import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/application/ports/cueing_port.dart';
import 'package:parkinstep/di/clinical_session_providers.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/di/session_prep_providers.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/domain/enums/preview_gait_scenario.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/live_session/screens/live_session_screen.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyCueingPort implements CueingPort {
  int beatCalls = 0;

  @override
  Future<void> playMetronomeBeat({
    required bool accented,
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    beatCalls++;
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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('S-05 Framing/Calibration, S-06 Live HUD & S-08 Fall Guard Verification',
      () {
    testWidgets(
        'End-to-end S-04 -> S-05 (LowLight error & retry) -> Calibration -> S-06 (Two-Tier FoG) -> S-08 Fall Guard -> Summary persists to S-03',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _SpyCueingPort();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cueingPortProvider.overrideWithValue(cueing),
          ],
          child: const ParkinStepApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter S-04 from S-03 & complete all 4 checks
      await tester.tap(find.byKey(const Key('home_card_tes_360')));
      await tester.pumpAndSettle();
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
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('preflight_continue_button')),
      );
      await tester.tap(find.byKey(const Key('preflight_continue_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Now on S-05 Framing
      expect(find.byKey(const Key('live_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('calibration_status_card')), findsOneWidget);

      // Simulate low-light occlusion > 3s -> triggers R-27 State/ErrorLowLight
      await tester.ensureVisible(
        find.byKey(const Key('preview_scenario_lowLightOcclusion')),
      );
      await tester.tap(
        find.byKey(const Key('preview_scenario_lowLightOcclusion')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('low_light_error_card')), findsOneWidget);
      expect(find.text(ClinicalCopy.errorLowLightTitle), findsOneWidget);

      // Restore lighting & retry calibration -> moves through 2s framing + 3s calibration -> S-06
      await tester.ensureVisible(
        find.byKey(const Key('preview_scenario_normalGait')),
      );
      await tester.tap(find.byKey(const Key('preview_scenario_normalGait')));
      await tester.pump(const Duration(milliseconds: 150));

      await tester.ensureVisible(find.byKey(const Key('low_light_retry_button')));
      await tester.tap(find.byKey(const Key('low_light_retry_button')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('low_light_error_card')), findsNothing);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Now on S-06 Live Recording HUD
      expect(find.byKey(const Key('live_risk_gauge')), findsOneWidget);
      expect(find.byKey(const Key('live_highlight_prompt')), findsOneWidget);
      expect(find.text('NORMAL GAIT'), findsOneWidget);

      // Simulate confirmed FoG: 1st second EARLY_WARNING, 2nd second FOG_CONFIRMED
      await tester.ensureVisible(
        find.byKey(const Key('preview_scenario_confirmedFog')),
      );
      await tester.tap(find.byKey(const Key('preview_scenario_confirmedFog')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('PERINGATAN DINI'), findsOneWidget);
      expect(find.text(ClinicalCopy.livePromptWarningHighlight), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('KAKI MEMBEKU'), findsOneWidget);
      expect(find.text(ClinicalCopy.livePromptFogHighlight), findsOneWidget);
      expect(cueing.beatCalls, greaterThanOrEqualTo(1));

      // Simulate sudden fall >= 0.65 & immobile 3s -> triggers S-08 Fall Guard
      await tester.ensureVisible(
        find.byKey(const Key('preview_scenario_suddenFall')),
      );
      await tester.tap(find.byKey(const Key('preview_scenario_suddenFall')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('fall_guard_screen')), findsOneWidget);
      expect(find.text(ClinicalCopy.fallGuardTitle), findsOneWidget);

      // Patient cancels alarm -> returns cleanly to S-06
      await tester.ensureVisible(
        find.byKey(const Key('fall_guard_im_ok_button')),
      );
      await tester.tap(find.byKey(const Key('fall_guard_im_ok_button')));
      await tester.pump();
      expect(find.byKey(const Key('fall_guard_screen')), findsNothing);
      expect(find.byKey(const Key('live_finish_test_button')), findsOneWidget);

      // Finish session -> postSessionAnalyzing -> summaryReady
      await tester.ensureVisible(
        find.byKey(const Key('live_finish_test_button')),
      );
      await tester.tap(find.byKey(const Key('live_finish_test_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('post_session_summary_screen')),
        findsOneWidget,
      );
      expect(find.text('Ringkasan Sesi Tes 360°'), findsOneWidget);

      // Return to S-03 Home & verify session persisted in MetricPill (no empty state)
      await tester.ensureVisible(find.byKey(const Key('summary_home_button')));
      await tester.tap(find.byKey(const Key('summary_home_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih untuk Memulai'), findsOneWidget);
      expect(find.byKey(const Key('home_empty_history_state')), findsNothing);
      expect(find.text('Belum Ada Tes'), findsNothing);
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: S-05, S-06 & S-08 render zero overflow & >= 56/64/88dp touch targets',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _SpyCueingPort();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cueingPortProvider.overrideWithValue(cueing),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const LiveSessionScreen();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      // S-05 Framing touch target
      final cancelSize =
          tester.getSize(find.byKey(const Key('live_cancel_button')));
      expect(cancelSize.height, greaterThanOrEqualTo(56.0));

      // Advance to S-06 Live HUD
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
      final finishSize =
          tester.getSize(find.byKey(const Key('live_finish_test_button')));
      expect(finishSize.height, greaterThanOrEqualTo(64.0));

      // Advance to S-08 Fall Guard & verify >= 88 dp Im OK CTA
      capturedRef
          .read(clinicalSessionControllerProvider.notifier)
          .setPreviewScenario(PreviewGaitScenario.suddenFall);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fall_guard_screen')), findsOneWidget);

      final imOkSize =
          tester.getSize(find.byKey(const Key('fall_guard_im_ok_button')));
      final escalateSize = tester.getSize(
        find.byKey(const Key('fall_guard_escalate_button')),
      );
      expect(imOkSize.height, greaterThanOrEqualTo(88.0));
      expect(escalateSize.height, greaterThanOrEqualTo(56.0));
    });
  });
}
