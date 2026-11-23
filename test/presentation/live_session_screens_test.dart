import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/application/ports/cueing_port.dart';
import 'package:parkinstep/application/ports/voice_guide_port.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/di/session_prep_providers.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/live_session/screens/live_session_screen.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyCueingPort implements CueingPort {
  int beatCalls = 0;
  int completionCalls = 0;

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
  }) async {
    completionCalls++;
  }
}

class _SpyVoiceGuidePort implements VoiceGuidePort {
  final List<String> spokenTexts = <String>[];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
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

  group('Video-Based 3-Test Recording, Review, Retake & Post-Recording Pose Extraction', () {
    testWidgets(
        'End-to-end: Select Duduk-Berdiri -> Pre-Flight -> Ready -> Countdown 3-2-1 -> Guided Record (0s & 30s voice cues, NO live skeleton) -> Review (Retake) -> Re-record -> Kirim -> Pose Analysis -> Summary persisted to S-03',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _SpyCueingPort();
      final voice = _SpyVoiceGuidePort();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cueingPortProvider.overrideWithValue(cueing),
            voiceGuideProvider.overrideWithValue(voice),
          ],
          child: const ParkinStepApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Mulai Tes -> select Duduk-Berdiri -> complete S-04 safety checklist
      await tester.tap(find.byKey(const Key('home_card_tes_360')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('test_card_sitToStand')));
      await tester.tap(find.byKey(const Key('test_card_sitToStand')));
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
      await tester.pumpAndSettle();

      // 2. Now in ReadyToRecord: clean camera view, NO skeleton or live FoG gauge
      expect(find.byKey(const Key('record_ready_card')), findsOneWidget);
      expect(find.byKey(const Key('record_start_button')), findsOneWidget);
      expect(find.textContaining('Sendi LB6'), findsNothing);
      expect(find.text('Risiko FoG'), findsNothing);

      // 3. Start countdown (3-2-1) -> enters RecordingActive
      await tester.ensureVisible(find.byKey(const Key('record_start_button')));
      await tester.tap(find.byKey(const Key('record_start_button')));
      await tester.pump();
      expect(
        find.byKey(const Key('recording_countdown_screen')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      // 4. Now actively recording video with 0s instruction & voice cue
      expect(find.byKey(const Key('recording_rec_badge')), findsOneWidget);
      expect(find.byKey(const Key('live_progress_pill')), findsOneWidget);
      expect(find.byKey(const Key('live_highlight_prompt')), findsOneWidget);
      expect(find.text('DUDUK LALU BERDIRI'), findsOneWidget);
      expect(voice.spokenTexts.length, 1);
      expect(find.textContaining('Sendi LB6'), findsNothing);
      expect(find.text('Risiko FoG'), findsNothing);

      // Advance 30s -> timed instruction & voice cue update cleanly
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('JAGA RITME'), findsOneWidget);
      expect(voice.spokenTexts.length, 2);

      // Stop recording -> Review screen
      await tester.ensureVisible(find.byKey(const Key('record_stop_button')));
      await tester.tap(find.byKey(const Key('record_stop_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_recorded_screen')), findsOneWidget);
      expect(find.text('Durasi Rekaman: 30 detik'), findsOneWidget);
      expect(find.byKey(const Key('record_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('record_retake_button')), findsOneWidget);

      // 5. Test Retake -> back to readyToRecord
      await tester.ensureVisible(find.byKey(const Key('record_retake_button')));
      await tester.tap(find.byKey(const Key('record_retake_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('record_ready_card')), findsOneWidget);

      // 6. Re-record >= 3s, pick confirmed FoG scenario, submit via Kirim -> Analyzing -> Summary
      await tester.ensureVisible(find.byKey(const Key('record_start_button')));
      await tester.tap(find.byKey(const Key('record_start_button')));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(const Key('preview_scenario_confirmedFog')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(const Key('record_stop_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('record_submit_button')));
      await tester.tap(find.byKey(const Key('record_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('post_session_summary_screen')),
        findsOneWidget,
      );
      expect(find.text('Ringkasan Tes Duduk-Berdiri'), findsOneWidget);

      // 7. Return to S-03 Home & verify Duduk-Berdiri session persisted
      await tester.ensureVisible(find.byKey(const Key('summary_home_button')));
      await tester.tap(find.byKey(const Key('summary_home_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih untuk Memulai'), findsOneWidget);
      expect(find.byKey(const Key('home_empty_history_state')), findsNothing);
      expect(find.textContaining('Duduk-Berdiri · ON Obat'), findsOneWidget);
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: Ready, Countdown, Recording, Review & Analyzing render zero overflow & >= 56/64dp touch targets',
        (WidgetTester tester) async {
      final prefs = await _seedCompletedPrefs();
      final cueing = _SpyCueingPort();
      final voice = _SpyVoiceGuidePort();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cueingPortProvider.overrideWithValue(cueing),
            voiceGuideProvider.overrideWithValue(voice),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const LiveSessionScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const Key('live_cancel_button'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('record_sound_toggle'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('record_start_button'))).height,
        greaterThanOrEqualTo(64.0),
      );

      // Enter countdown
      await tester.ensureVisible(find.byKey(const Key('record_start_button')));
      await tester.tap(find.byKey(const Key('record_start_button')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('countdown_cancel_button'))).height,
        greaterThanOrEqualTo(56.0),
      );

      // Advance into recordingActive & check >= 64dp stop button
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('record_stop_button'))).height,
        greaterThanOrEqualTo(64.0),
      );

      // Stop < 3s (at 1s) -> verify short-video warning appears without overflow
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('record_stop_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('short_video_warning')), findsOneWidget);
      expect(find.text(ClinicalCopy.reviewShortVideoWarning), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('record_submit_button'))).height,
        greaterThanOrEqualTo(64.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('record_retake_button'))).height,
        greaterThanOrEqualTo(64.0),
      );

      // Retake & record 4s -> Kirim -> check analyzingVideo A11y card + cancel button
      await tester.ensureVisible(find.byKey(const Key('record_retake_button')));
      await tester.tap(find.byKey(const Key('record_retake_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('record_start_button')));
      await tester.tap(find.byKey(const Key('record_start_button')));
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(const Key('record_stop_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('record_submit_button')));
      await tester.tap(find.byKey(const Key('record_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('loading_dsp_card')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('analysis_cancel_button'))).height,
        greaterThanOrEqualTo(56.0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
