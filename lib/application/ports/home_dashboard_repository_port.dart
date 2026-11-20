import '../../domain/entities/home_dashboard_summary.dart';
import '../../domain/entities/medication_log.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/session_summary_item.dart';

/// Persistence contract for S-03 Beranda dashboard summaries, reports & medication logs.
abstract interface class HomeDashboardRepositoryPort {
  Future<HomeDashboardSummary> loadSummary();

  Future<HomeDashboardSummary> addMedicationLog(MedicationLog log);

  Future<HomeDashboardSummary> saveSessionSummary(SessionSummaryItem session);

  Future<void> saveSessionReport(SessionClinicalReport report);

  Future<SessionClinicalReport?> loadSessionReport(String sessionId);

  Future<HomeDashboardSummary> dismissReminderForDate(String localDateIso);

  Future<void> clearAll();
}
