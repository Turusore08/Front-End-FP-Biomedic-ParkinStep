import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkinstep/app/app.dart';
import 'package:parkinstep/application/ports/recorded_media_port.dart';
import 'package:parkinstep/application/ports/report_export_port.dart';
import 'package:parkinstep/di/analytics_providers.dart';
import 'package:parkinstep/di/dashboard_providers.dart';
import 'package:parkinstep/di/onboarding_providers.dart';
import 'package:parkinstep/di/video_playback_providers.dart';
import 'package:parkinstep/domain/constants/clinical_copy.dart';
import 'package:parkinstep/domain/entities/consent_preferences.dart';
import 'package:parkinstep/domain/entities/fog_episode_item.dart';
import 'package:parkinstep/domain/entities/onboarding_status.dart';
import 'package:parkinstep/domain/entities/recorded_pose_track.dart';
import 'package:parkinstep/domain/entities/session_clinical_report.dart';
import 'package:parkinstep/domain/entities/session_summary_item.dart';
import 'package:parkinstep/domain/entities/window_prediction_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/onboarding_auth_mode.dart';
import 'package:parkinstep/domain/value_objects/keypoint_2d.dart';
import 'package:parkinstep/infrastructure/export/clinical_csv_exporter.dart';
import 'package:parkinstep/infrastructure/export/clinical_pdf_exporter.dart';
import 'package:parkinstep/infrastructure/persistence/local_home_dashboard_repository.dart';
import 'package:parkinstep/infrastructure/persistence/local_onboarding_repository.dart';
import 'package:parkinstep/presentation/features/analytics/painters/recorded_skeleton_overlay_painter.dart';
import 'package:parkinstep/presentation/features/analytics/screens/session_report_screen.dart';
import 'package:parkinstep/presentation/features/history/screens/history_tab_screen.dart';
import 'package:parkinstep/presentation/features/settings/screens/settings_tab_screen.dart';
import 'package:parkinstep/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryRecordedMediaPort implements RecordedMediaPort {
  final Map<String, RecordedPoseTrack> tracks = <String, RecordedPoseTrack>{};
  int deleteCalls = 0;
  int deleteAllCalls = 0;

  @override
  Future<({String videoPath, String poseTrackPath})> saveSessionMedia({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
  }) async {
    final posePath = 'mem://$sessionId.pose.json';
    tracks[posePath] = poseTrack;
    return (videoPath: sourceVideoPath, poseTrackPath: posePath);
  }

  @override
  Future<RecordedPoseTrack?> loadPoseTrack(String poseTrackPath) async =>
      tracks[poseTrackPath];

  @override
  Future<void> deleteSessionMedia({
    String? videoPath,
    String? poseTrackPath,
  }) async {
    deleteCalls++;
    if (poseTrackPath != null) {
      tracks.remove(poseTrackPath);
    }
  }

  @override
  Future<void> deleteAllSessionMedia() async {
    deleteAllCalls++;
    tracks.clear();
  }

  @override
  Future<ExportedSkeletonVideoResult> exportSkeletonMp4({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
    required List<FogEpisodeItem> episodes,
  }) async {
    return ExportedSkeletonVideoResult(
      savedPath: '/mock/Movies/ParkinStep/parkinstep_skeleton_$sessionId.mp4',
      savedToGallery: true,
      sizeBytes: 2048,
    );
  }
}

class _SyncFileTestExportPort implements ReportExportPort {
  _SyncFileTestExportPort(this.targetDir);

  final Directory targetDir;

  @override
  Future<ExportedReportFile> generatePdfReport(SessionClinicalReport report) {
    return const ClinicalPdfExporter().generate(report);
  }

  @override
  Future<ExportedReportFile> generateCsvReport(
    SessionClinicalReport report,
  ) async {
    return const ClinicalCsvExporter().generate(report);
  }

  @override
  Future<ExportedReportFile> saveReportFile(ExportedReportFile file) async {
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final out = File('${targetDir.path}/${file.fileName}');
    out.writeAsBytesSync(file.bytes, flush: true);
    return file.copyWith(savedPath: out.path);
  }
}

Future<SharedPreferences> _seedAnalyticsPrefs({
  required List<SessionSummaryItem> sessions,
  List<SessionClinicalReport> reports = const <SessionClinicalReport>[],
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
        consentSkeletonSync: false,
        consentCloudVideo: false,
        acceptedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
      ),
    ),
  );
  final repo = LocalHomeDashboardRepository(prefs);
  for (final s in sessions) {
    await repo.saveSessionSummary(s);
  }
  for (final r in reports) {
    await repo.saveSessionReport(r);
  }
  return prefs;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('S-09 Clinical Summary & Export + S-10 Riwayat ON/OFF Trends', () {
    testWidgets(
        'S-09 renders zero-episode & multi-episode charts, interactive episode chip, and offline PDF/CSV export confirmation',
        (WidgetTester tester) async {
      final exportDir = Directory.systemTemp.createTempSync('parkinstep_ui_exp_');
      addTearDown(() => exportDir.deleteSync(recursive: true));

      final zeroSummary = SessionSummaryItem(
        sessionId: 'sess-zero',
        startedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
        medState: MedicationState.on,
        fogPercentage: 0.0,
        episodeCount: 0,
        durationSec: 60.0,
      );
      final epReport = SessionClinicalReport(
        summary: SessionSummaryItem(
          sessionId: 'sess-fog',
          startedAtUtc: DateTime.utc(2026, 11, 19, 8, 0),
          medState: MedicationState.off,
          fogPercentage: 22.0,
          episodeCount: 1,
          durationSec: 60.0,
        ),
        patientDisplayName: 'Pak Budi',
        meanFreezeIndex: 2.18,
        meanBilateralAsymmetry: 0.27,
        episodes: const <FogEpisodeItem>[
          FogEpisodeItem(
            episodeIndex: 1,
            startSec: 12.0,
            endSec: 16.0,
            peakCalibratedScore: 81.5,
            meanFreezeIndex: 2.18,
          ),
        ],
        windows: List<WindowPredictionItem>.generate(
          20,
          (i) => WindowPredictionItem(
            windowIdx: i,
            startSec: i * 3.0,
            endSec: (i + 1) * 3.0,
            rawProb: i == 4 || i == 5 ? 0.68 : 0.09,
            calibratedScore: i == 4 || i == 5 ? 78.4 : 17.3,
            predRaw: i == 4 || i == 5,
            predPostprocessed: i == 4 || i == 5,
            freezeIndexAnkle: i == 4 || i == 5 ? 2.18 : 0.41,
            bilateralAsymAnkle: 0.27,
          ),
        ),
      );

      final prefs = await _seedAnalyticsPrefs(
        sessions: <SessionSummaryItem>[zeroSummary, epReport.summary],
        reports: <SessionClinicalReport>[epReport],
      );

      // Zero-episode fallback check
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reportExportPortProvider.overrideWithValue(
              _SyncFileTestExportPort(exportDir),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SessionReportScreen(sessionId: 'sess-zero'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ClinicalCopy.reportZeroEpisodeBadge), findsOneWidget);
      expect(find.text('0,0%'), findsOneWidget);

      // Multi-episode interactive tap + offline PDF & CSV export
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reportExportPortProvider.overrideWithValue(
              _SyncFileTestExportPort(exportDir),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SessionReportScreen(sessionId: 'sess-fog'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('22,0%'), findsOneWidget);
      expect(find.text('Tinggi'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('episode_chip_1')));
      await tester.tap(find.byKey(const Key('episode_chip_1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('timeline_selected_episode_detail')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('export_pdf_button')));
      await tester.tap(find.byKey(const Key('export_pdf_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('export_status_banner')), findsOneWidget);
      expect(find.textContaining('parkinstep_laporan_sess-fog.pdf'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('export_csv_button')));
      await tester.tap(find.byKey(const Key('export_csv_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('parkinstep_sess-fog.csv'), findsOneWidget);
    });

    testWidgets(
        'S-10 filters 7 Hari / 30 Hari / Semua across ON/OFF sessions and drills down to S-09',
        (WidgetTester tester) async {
      final fixedClock = DateTime(2026, 11, 20, 10, 0);
      final sRecent = SessionSummaryItem(
        sessionId: 'sess-recent',
        startedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
        medState: MedicationState.on,
        fogPercentage: 4.5,
        episodeCount: 0,
        durationSec: 120.0,
      );
      final sMid = SessionSummaryItem(
        sessionId: 'sess-mid',
        startedAtUtc: DateTime.utc(2026, 11, 8, 8, 0), // 12 days ago
        medState: MedicationState.off,
        fogPercentage: 28.0,
        episodeCount: 3,
        durationSec: 120.0,
      );
      final sOld = SessionSummaryItem(
        sessionId: 'sess-old',
        startedAtUtc: DateTime.utc(2026, 10, 1, 8, 0), // 50 days ago
        medState: MedicationState.on,
        fogPercentage: 9.0,
        episodeCount: 1,
        durationSec: 120.0,
      );

      final prefs = await _seedAnalyticsPrefs(
        sessions: <SessionSummaryItem>[sRecent, sMid, sOld],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeDashboardClockProvider.overrideWithValue(() => fixedClock),
          ],
          child: const ParkinStepApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_tab_history')));
      await tester.pumpAndSettle();

      expect(find.text(ClinicalCopy.historyScreenTitle), findsOneWidget);
      expect(find.text(ClinicalCopy.historyModelMetadata), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-recent')), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-mid')), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-old')), findsOneWidget);

      // Filter 30 Hari hides sess-old (50d) while keeping sess-recent & sess-mid
      await tester.tap(find.byKey(const Key('history_filter_30d')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_session_sess-recent')), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-mid')), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-old')), findsNothing);

      // Filter 7 Hari keeps only sess-recent
      await tester.tap(find.byKey(const Key('history_filter_7d')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_session_sess-recent')), findsOneWidget);
      expect(find.byKey(const Key('history_session_sess-mid')), findsNothing);

      // Drill down from S-10 list row into S-09 SessionReportScreen
      await tester.ensureVisible(
        find.byKey(const Key('history_session_sess-recent')),
      );
      await tester.tap(find.byKey(const Key('history_session_sess-recent')));
      await tester.pumpAndSettle();
      expect(find.text(ClinicalCopy.reportScreenTitle), findsOneWidget);
    });

    testWidgets(
        'A11y 360x640 @ 1.5x TextScaler: S-09 & S-10 render zero overflow with compliant touch targets',
        (WidgetTester tester) async {
      final sessions = <SessionSummaryItem>[
        SessionSummaryItem(
          sessionId: 'sess-a11y-1',
          startedAtUtc: DateTime.utc(2026, 11, 20, 8, 0),
          medState: MedicationState.on,
          fogPercentage: 3.2,
          episodeCount: 0,
          durationSec: 120.0,
        ),
        SessionSummaryItem(
          sessionId: 'sess-a11y-2',
          startedAtUtc: DateTime.utc(2026, 11, 19, 8, 0),
          medState: MedicationState.off,
          fogPercentage: 21.5,
          episodeCount: 2,
          durationSec: 120.0,
        ),
      ];
      final report = SessionClinicalReport(
        summary: sessions[1],
        patientDisplayName: 'Pak Budi',
        meanFreezeIndex: 2.1,
        meanBilateralAsymmetry: 0.24,
        episodes: const <FogEpisodeItem>[
          FogEpisodeItem(
            episodeIndex: 1,
            startSec: 10.0,
            endSec: 14.0,
            peakCalibratedScore: 78.0,
            meanFreezeIndex: 2.1,
          ),
        ],
      );
      final prefs = await _seedAnalyticsPrefs(
        sessions: sessions,
        reports: <SessionClinicalReport>[report],
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // S-09 at 360x640 @ 1.5x
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const SessionReportScreen(sessionId: 'sess-a11y-2'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const Key('report_back_button'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('export_pdf_button'))).height,
        greaterThanOrEqualTo(64.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('export_csv_button'))).height,
        greaterThanOrEqualTo(64.0),
      );

      // S-10 at 360x640 @ 1.5x
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const HistoryTabScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const Key('history_filter_7d'))).height,
        greaterThanOrEqualTo(56.0),
      );
      expect(
        tester.getSize(find.byKey(const Key('history_session_sess-a11y-1'))).height,
        greaterThanOrEqualTo(64.0),
      );
    });

    testWidgets(
        'S-09 hydrates & replays locally saved video + skeleton track and supports manual deletion, plus SettingsTabScreen delete-all videos @ 1.5x A11y',
        (WidgetTester tester) async {
      final mediaPort = _InMemoryRecordedMediaPort();
      const posePath = 'mem://sess-video.pose.json';
      mediaPort.tracks[posePath] = RecordedPoseTrack(
        imageWidth: 480.0,
        imageHeight: 640.0,
        durationMs: 4000,
        frames: <TimedPoseFrame>[
          TimedPoseFrame(
            timestampMs: 0,
            keypoints17: List<Keypoint2D>.generate(
              17,
              (k) => Keypoint2D(
                x: 200.0 + (k * 3),
                y: 120.0 + (k * 20),
                conf: 0.92,
              ),
            ),
          ),
          TimedPoseFrame(
            timestampMs: 2000,
            keypoints17: List<Keypoint2D>.generate(
              17,
              (k) => Keypoint2D(
                x: 210.0 + (k * 3),
                y: 125.0 + (k * 20),
                conf: 0.90,
              ),
            ),
          ),
        ],
      );

      final videoSummary = SessionSummaryItem(
        sessionId: 'sess-video',
        startedAtUtc: DateTime.utc(2026, 11, 22, 9, 0),
        medState: MedicationState.off,
        fogPercentage: 18.0,
        episodeCount: 1,
        durationSec: 4.0,
      );
      final videoReport = SessionClinicalReport(
        summary: videoSummary,
        patientDisplayName: 'Pak Budi',
        videoSecurelyDeleted: false,
        recordedVideoPath: 'preview://test_s09.mp4',
        poseTrackPath: posePath,
        episodes: const <FogEpisodeItem>[
          FogEpisodeItem(
            episodeIndex: 1,
            startSec: 1.0,
            endSec: 2.5,
            peakCalibratedScore: 76.0,
            meanFreezeIndex: 1.9,
          ),
        ],
      );
      final prefs = await _seedAnalyticsPrefs(
        sessions: <SessionSummaryItem>[videoSummary],
        reports: <SessionClinicalReport>[videoReport],
      );

      // 1. S-09 replays & deletes saved local video + skeleton
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recordedMediaPortProvider.overrideWithValue(mediaPort),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SessionReportScreen(sessionId: 'sess-video'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('video_skeleton_player_card')),
        findsOneWidget,
      );
      final paintFinder =
          find.byKey(const Key('recorded_skeleton_custom_paint'));
      expect(paintFinder, findsOneWidget);
      expect(
        tester.widget<CustomPaint>(paintFinder).painter,
        isA<RecordedSkeletonOverlayPainter>(),
      );

      await tester.ensureVisible(find.byKey(const Key('video_delete_button')));
      await tester.tap(find.byKey(const Key('video_delete_button')));
      await tester.pumpAndSettle();

      expect(mediaPort.deleteCalls, 1);
      expect(find.byKey(const Key('video_deleted_banner')), findsOneWidget);
      expect(find.byKey(const Key('video_skeleton_player_card')), findsNothing);

      // 2. SettingsTabScreen delete-all videos @ 360x640 with 1.5x TextScaler
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recordedMediaPortProvider.overrideWithValue(mediaPort),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const SettingsTabScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final deleteAllFinder =
          find.byKey(const Key('settings_delete_all_videos_button'));
      await tester.ensureVisible(deleteAllFinder);
      expect(tester.getSize(deleteAllFinder).height, greaterThanOrEqualTo(56.0));
      await tester.tap(deleteAllFinder);
      await tester.pumpAndSettle();

      expect(mediaPort.deleteAllCalls, 1);
      expect(
        find.byKey(const Key('settings_videos_deleted_banner')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
