import 'medication_log.dart';
import 'session_summary_item.dart';

/// Aggregated offline-first dashboard state rendered on S-03 & Riwayat tab.
class HomeDashboardSummary {
  const HomeDashboardSummary({
    this.recentSessions = const <SessionSummaryItem>[],
    this.medicationLogs = const <MedicationLog>[],
    this.dismissedReminderDateIso,
  });

  /// Completed screening sessions sorted newest first.
  final List<SessionSummaryItem> recentSessions;

  /// Logged medication intakes sorted newest first.
  final List<MedicationLog> medicationLogs;

  /// Local calendar date ('YYYY-MM-DD') on which daily reminder was dismissed.
  final String? dismissedReminderDateIso;

  SessionSummaryItem? get latestSession =>
      recentSessions.isEmpty ? null : recentSessions.first;

  MedicationLog? get latestMedicationLog =>
      medicationLogs.isEmpty ? null : medicationLogs.first;

  bool get hasRealSessions => recentSessions.isNotEmpty;

  bool isReminderDismissedOn(String localDateIso) =>
      dismissedReminderDateIso == localDateIso;

  HomeDashboardSummary copyWith({
    List<SessionSummaryItem>? recentSessions,
    List<MedicationLog>? medicationLogs,
    String? dismissedReminderDateIso,
    bool clearDismissedReminderDate = false,
  }) {
    return HomeDashboardSummary(
      recentSessions: recentSessions ?? this.recentSessions,
      medicationLogs: medicationLogs ?? this.medicationLogs,
      dismissedReminderDateIso: clearDismissedReminderDate
          ? null
          : (dismissedReminderDateIso ?? this.dismissedReminderDateIso),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeDashboardSummary &&
        _listsEqual(other.recentSessions, recentSessions) &&
        _listsEqual(other.medicationLogs, medicationLogs) &&
        other.dismissedReminderDateIso == dismissedReminderDateIso;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(recentSessions),
        Object.hashAll(medicationLogs),
        dismissedReminderDateIso,
      );

  static bool _listsEqual<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
