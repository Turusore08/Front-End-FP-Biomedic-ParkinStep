import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/entities/fog_episode_item.dart';
import 'package:parkinstep/domain/entities/session_clinical_report.dart';
import 'package:parkinstep/domain/entities/session_summary_item.dart';
import 'package:parkinstep/domain/entities/window_prediction_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_protocol.dart';
import 'package:parkinstep/infrastructure/export/clinical_csv_exporter.dart';
import 'package:parkinstep/infrastructure/export/clinical_pdf_exporter.dart';
import 'package:parkinstep/infrastructure/export/local_report_export_adapter.dart';
import 'package:parkinstep/infrastructure/persistence/local_home_dashboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Clinical PDF/CSV Export & Report Persistence Edge Cases', () {
    test(
        'Zero-episode edge case (PDFE10_1) computes finite 0 median and exports clean PDF & CSV',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('parkinstep_pdfe10_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final windows = List<WindowPredictionItem>.generate(
        30,
        (i) => WindowPredictionItem(
          windowIdx: i,
          startSec: i.toDouble(),
          endSec: i + 2.0,
          rawProb: 0.06,
          calibratedScore: 11.5,
          predRaw: false,
          predPostprocessed: false,
          freezeIndexAnkle: 0.42,
          bilateralAsymAnkle: 0.07,
        ),
      );

      final report = SessionClinicalReport(
        summary: SessionSummaryItem(
          sessionId: 'PDFE10_1',
          startedAtUtc: DateTime.utc(2026, 11, 20, 8, 15),
          medState: MedicationState.on,
          fogPercentage: 0.0,
          episodeCount: 0,
          durationSec: 120.0,
        ),
        patientDisplayName: 'Pak Budi',
        totalFogDurationSec: 0.0,
        medianEpisodeDurationSec: SessionClinicalReport.computeMedianEpisodeDuration(
          const <FogEpisodeItem>[],
        ),
        locomotorBandEnergy: 4.8,
        freezeBandEnergy: 0.5,
        meanFreezeIndex: 0.42,
        meanBilateralAsymmetry: 0.07,
        episodes: const <FogEpisodeItem>[],
        windows: windows,
      );

      expect(report.medianEpisodeDurationSec, 0.0);
      expect(report.medianEpisodeDurationSec.isFinite, isTrue);

      final adapter = LocalReportExportAdapter(
        targetDirectoryProvider: () => tempDir,
      );

      final pdf = await adapter.saveReportFile(
        await adapter.generatePdfReport(report),
      );
      expect(pdf.savedPath, isNotNull);
      expect(File(pdf.savedPath!).existsSync(), isTrue);
      expect(utf8.decode(pdf.bytes.take(5).toList()), '%PDF-');
      expect(pdf.bytes.length, greaterThan(500));

      final csvFile = await adapter.saveReportFile(
        await adapter.generateCsvReport(report),
      );
      expect(File(csvFile.savedPath!).existsSync(), isTrue);
      final csvText = utf8.decode(csvFile.bytes).trim();
      final lines = csvText.split('\n');
      expect(lines.length, 31); // 1 header + 30 window rows
      expect(
        lines.first.trim(),
        ClinicalCsvExporter.headers.join(','),
      );
    });

    test(
        'Severe continuous FoG edge case (PDFE01_1: 96.6%, 25 episodes, 118 windows) paginates A4 PDF & writes 16-col CSV',
        () async {
      final episodes = List<FogEpisodeItem>.generate(
        25,
        (i) => FogEpisodeItem(
          episodeIndex: i + 1,
          startSec: i * 4.5,
          endSec: i * 4.5 + 3.8,
          peakCalibratedScore: 88.5,
          meanFreezeIndex: 2.64,
        ),
      );
      final windows = List<WindowPredictionItem>.generate(
        118,
        (i) => WindowPredictionItem(
          windowIdx: i,
          startSec: i.toDouble(),
          endSec: i + 2.0,
          rawProb: i < 114 ? 0.72 : 0.12,
          calibratedScore: i < 114 ? 81.1 : 23.0,
          predRaw: i < 114,
          predPostprocessed: i < 114,
          freezeIndexAnkle: i < 114 ? 2.64 : 0.55,
          bilateralAsymAnkle: 0.31,
        ),
      );

      final report = SessionClinicalReport(
        summary: SessionSummaryItem(
          sessionId: 'PDFE01_1',
          startedAtUtc: DateTime.utc(2026, 11, 20, 9, 0),
          medState: MedicationState.off,
          fogPercentage: 96.6,
          episodeCount: 25,
          durationSec: 120.0,
        ),
        patientDisplayName: 'Ibu Sari',
        totalFogDurationSec: 114.0,
        medianEpisodeDurationSec:
            SessionClinicalReport.computeMedianEpisodeDuration(episodes),
        locomotorBandEnergy: 1.9,
        freezeBandEnergy: 6.4,
        meanFreezeIndex: 2.64,
        meanBilateralAsymmetry: 0.31,
        episodes: episodes,
        windows: windows,
      );

      expect(report.asymmetryLevelId, 'Tinggi');
      expect(report.medianEpisodeDurationSec, closeTo(3.8, 1e-6));

      final pdf = await const ClinicalPdfExporter().generate(report);
      expect(utf8.decode(pdf.bytes.take(5).toList()), '%PDF-');
      expect(pdf.bytes.length, greaterThan(1500));

      final csvFile = const ClinicalCsvExporter().generate(report);
      final lines = utf8.decode(csvFile.bytes).trim().split('\n');
      expect(lines.length, 119); // 1 header + 118 rows
      expect(lines[1].split(',').length, 16);
      expect(lines[1], contains('PDFE01_1'));
    });

    test(
        'LocalHomeDashboardRepository persists & loads SessionClinicalReport traces and handles missing/corrupt data',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalHomeDashboardRepository(prefs);

      final report = SessionClinicalReport(
        summary: SessionSummaryItem(
          sessionId: 'sess-repo-1',
          startedAtUtc: DateTime.utc(2026, 11, 20, 7, 30),
          protocol: SessionProtocol.walkBackAndForth,
          medState: MedicationState.on,
          fogPercentage: 15.0,
          episodeCount: 1,
          durationSec: 20.0,
        ),
        patientDisplayName: 'Pak Budi',
        meanFreezeIndex: 1.45,
        meanBilateralAsymmetry: 0.14,
        episodes: const <FogEpisodeItem>[
          FogEpisodeItem(
            episodeIndex: 1,
            startSec: 4.0,
            endSec: 7.0,
            peakCalibratedScore: 76.0,
            meanFreezeIndex: 1.85,
          ),
        ],
        windows: const <WindowPredictionItem>[
          WindowPredictionItem(
            windowIdx: 0,
            startSec: 4.0,
            endSec: 6.0,
            rawProb: 0.62,
            calibratedScore: 74.3,
            predRaw: true,
            predPostprocessed: true,
            freezeIndexAnkle: 1.85,
            bilateralAsymAnkle: 0.14,
          ),
        ],
      );

      await repo.saveSessionReport(report);
      final loaded = await repo.loadSessionReport('sess-repo-1');
      expect(loaded, isNotNull);
      expect(loaded!.patientDisplayName, 'Pak Budi');
      expect(loaded.summary.protocol, SessionProtocol.walkBackAndForth);
      expect(loaded.episodes, hasLength(1));
      expect(loaded.episodes.first.durationSec, 3.0);
      expect(loaded.windows, hasLength(1));
      expect(await repo.loadSessionReport('unknown-id'), isNull);

      await prefs.setString(
        LocalHomeDashboardRepository.reportsStorageKey,
        '{corrupt-json',
      );
      expect(await repo.loadSessionReport('sess-repo-1'), isNull);
    });
  });
}
