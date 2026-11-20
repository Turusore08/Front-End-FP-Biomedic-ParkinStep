import '../../domain/entities/home_dashboard_summary.dart';
import '../ports/home_dashboard_repository_port.dart';

/// Records dismissal of the daily S-03 screening reminder for the local calendar date.
class DismissDailyReminder {
  DismissDailyReminder(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HomeDashboardRepositoryPort _repository;
  final DateTime Function() _clock;

  /// Formats a DateTime in local time as ISO 'YYYY-MM-DD'.
  static String formatLocalDateIso(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<HomeDashboardSummary> execute() {
    final todayIso = formatLocalDateIso(_clock());
    return _repository.dismissReminderForDate(todayIso);
  }
}
