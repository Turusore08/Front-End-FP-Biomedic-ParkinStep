import '../../domain/entities/home_dashboard_summary.dart';
import '../../domain/entities/medication_log.dart';
import '../../domain/entities/session_summary_item.dart';

/// Persistence contract for S-03 Beranda dashboard summaries & medication logs.
abstract interface class HomeDashboardRepositoryPort {
  Future<HomeDashboardSummary> loadSummary();

  Future<HomeDashboardSummary> addMedicationLog(MedicationLog log);

  Future<HomeDashboardSummary> saveSessionSummary(SessionSummaryItem session);

  Future<HomeDashboardSummary> dismissReminderForDate(String localDateIso);

  Future<void> clearAll();
}
