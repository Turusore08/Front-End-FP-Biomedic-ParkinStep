import 'session_clinical_report.dart';
import 'session_summary_item.dart';

/// Post-session result produced once temporary video cleanup & metric aggregation finish.
class CompletedSessionRecord {
  const CompletedSessionRecord({
    required this.summary,
    required this.peakRiskScore,
    required this.meanFreezeIndex,
    required this.totalFogDurationSec,
    required this.validLb6Ratio,
    required this.fallGuardFalseAlarms,
    required this.videoSecurelyDeleted,
    required this.isSimulatedPreview,
    this.report,
  });

  final SessionSummaryItem summary;
  final double peakRiskScore;
  final double meanFreezeIndex;
  final double totalFogDurationSec;
  final double validLb6Ratio;
  final int fallGuardFalseAlarms;
  final bool videoSecurelyDeleted;
  final bool isSimulatedPreview;
  final SessionClinicalReport? report;
}
