import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/report_export_port.dart';
import '../domain/entities/session_clinical_report.dart';
import '../infrastructure/export/local_report_export_adapter.dart';
import 'clinical_session_providers.dart';
import 'dashboard_providers.dart';
import 'onboarding_providers.dart';

final reportExportPortProvider = Provider<ReportExportPort>(
  (ref) => LocalReportExportAdapter(),
);

/// Resolves the full S-09 clinical report by sessionId, preferring the latest
/// active session record, then persisted reports, and falling back cleanly to
/// summary-only synthesis when legacy summaries exist without traces.
final sessionReportByIdProvider =
    FutureProvider.family<SessionClinicalReport?, String>(
  (ref, sessionId) async {
    final liveRecord = ref.watch(
      clinicalSessionControllerProvider.select((s) => s.completedRecord),
    );
    if (liveRecord != null &&
        liveRecord.summary.sessionId == sessionId &&
        liveRecord.report != null) {
      return liveRecord.report;
    }

    final repo = ref.read(homeDashboardRepositoryProvider);
    final persistedReport = await repo.loadSessionReport(sessionId);
    if (persistedReport != null) {
      return persistedReport;
    }

    final summary = await repo.loadSummary();
    final patientName = ref.read(onboardingControllerProvider).status.displayName;
    for (final item in summary.recentSessions) {
      if (item.sessionId == sessionId) {
        return SessionClinicalReport.fromSummaryOnly(
          item,
          patientDisplayName: patientName,
        );
      }
    }
    return null;
  },
);
