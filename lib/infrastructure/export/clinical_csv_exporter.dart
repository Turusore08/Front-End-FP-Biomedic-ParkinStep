import 'dart:convert';

import 'package:csv/csv.dart';

import '../../application/ports/report_export_port.dart';
import '../../domain/entities/session_clinical_report.dart';

/// Offline CSV serializer matching the 16-column research-parity schema in
/// `charts_and_pdf_blueprint.md` using `csv` 8.x `csv.encode`.
class ClinicalCsvExporter {
  const ClinicalCsvExporter();

  static const List<String> headers = <String>[
    'session_id',
    'patient_id',
    'started_at_utc',
    'med_state',
    'classifier_used',
    'threshold_used',
    'window_idx',
    'start_sec',
    'end_sec',
    'raw_prob',
    'calibrated_score',
    'pred_raw',
    'pred_postprocessed',
    'freeze_index_ankle',
    'bilateral_asym_ankle',
    'low_quality_flag',
  ];

  ExportedReportFile generate(SessionClinicalReport report) {
    final s = report.summary;
    final rows = <List<Object>>[headers];

    if (report.windows.isEmpty) {
      rows.add(<Object>[
        s.sessionId,
        report.patientDisplayName,
        s.startedAtUtc.toUtc().toIso8601String(),
        s.medState.storageValue,
        report.classifierUsed,
        report.thresholdUsed.toStringAsFixed(4),
        0,
        0.0,
        s.durationSec,
        0.0,
        s.fogPercentage,
        0,
        s.episodeCount > 0 ? 1 : 0,
        report.meanFreezeIndex.toStringAsFixed(4),
        report.meanBilateralAsymmetry.toStringAsFixed(4),
        0,
      ]);
    } else {
      for (final w in report.windows) {
        rows.add(<Object>[
          s.sessionId,
          report.patientDisplayName,
          s.startedAtUtc.toUtc().toIso8601String(),
          s.medState.storageValue,
          report.classifierUsed,
          report.thresholdUsed.toStringAsFixed(4),
          w.windowIdx,
          w.startSec.toStringAsFixed(2),
          w.endSec.toStringAsFixed(2),
          w.rawProb.toStringAsFixed(6),
          w.calibratedScore.toStringAsFixed(2),
          w.predRaw ? 1 : 0,
          w.predPostprocessed ? 1 : 0,
          w.freezeIndexAnkle.toStringAsFixed(4),
          w.bilateralAsymAnkle.toStringAsFixed(4),
          w.lowQualityFlag ? 1 : 0,
        ]);
      }
    }

    final encoded = csv.encode(rows);
    return ExportedReportFile(
      fileName: 'parkinstep_${s.sessionId}.csv',
      mimeType: 'text/csv',
      bytes: utf8.encode(encoded),
    );
  }
}
