import '../../domain/enums/medication_state.dart';
import '../../domain/errors/dashboard_failure.dart';
import '../ports/home_dashboard_repository_port.dart';
import '../use_cases/dismiss_daily_reminder.dart';
import '../use_cases/load_home_dashboard.dart';
import '../use_cases/log_medication_intake.dart';
import 'home_dashboard_ui_state.dart';

/// Pure Dart coordinator managing S-03 Beranda Dashboard data loading,
/// medication intake logging, and daily reminder dismissal.
class HomeDashboardCoordinator {
  HomeDashboardCoordinator({
    required HomeDashboardRepositoryPort repository,
    required this.readState,
    required this.writeState,
    DateTime Function()? clock,
  })  : _repository = repository,
        _clock = clock ?? DateTime.now,
        _loadHomeDashboard = LoadHomeDashboard(repository),
        _logMedicationIntake = LogMedicationIntake(repository, clock: clock),
        _dismissDailyReminder = DismissDailyReminder(repository, clock: clock);

  final HomeDashboardRepositoryPort _repository;
  final DateTime Function() _clock;
  final LoadHomeDashboard _loadHomeDashboard;
  final LogMedicationIntake _logMedicationIntake;
  final DismissDailyReminder _dismissDailyReminder;

  final HomeDashboardUiState Function() readState;
  final void Function(HomeDashboardUiState next) writeState;

  String get todayLocalDateIso =>
      DismissDailyReminder.formatLocalDateIso(_clock());

  Future<void> initialize() async {
    try {
      final loaded = await _loadHomeDashboard.execute();
      writeState(
        readState().copyWith(
          isInitialized: true,
          summary: loaded,
          clearError: true,
        ),
      );
    } on DashboardFailure catch (e) {
      writeState(
        readState().copyWith(
          isInitialized: true,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      writeState(
        readState().copyWith(
          isInitialized: true,
          errorMessage: 'Gagal memuat data beranda dari memori perangkat.',
        ),
      );
    }
  }

  /// Persists medication intake. Returns null on success or an Indonesian
  /// validation/storage message so bottom-sheet errors stay local to the sheet.
  Future<String?> logMedicationIntake({
    required String drugName,
    required double dosageMg,
    required MedicationState medState,
    String? notes,
  }) async {
    writeState(readState().copyWith(isBusy: true, clearError: true));
    try {
      final nextSummary = await _logMedicationIntake.execute(
        drugName: drugName,
        dosageMg: dosageMg,
        medState: medState,
        notes: notes,
      );
      writeState(
        readState().copyWith(
          isBusy: false,
          summary: nextSummary,
          clearError: true,
        ),
      );
      return null;
    } on DashboardFailure catch (e) {
      writeState(readState().copyWith(isBusy: false));
      return e.message;
    } catch (_) {
      writeState(readState().copyWith(isBusy: false));
      return 'Gagal menyimpan catatan obat. Silakan coba lagi.';
    }
  }

  Future<void> dismissDailyReminder() async {
    writeState(readState().copyWith(isBusy: true, clearError: true));
    try {
      final nextSummary = await _dismissDailyReminder.execute();
      writeState(
        readState().copyWith(
          isBusy: false,
          summary: nextSummary,
          clearError: true,
        ),
      );
    } on DashboardFailure catch (e) {
      writeState(
        readState().copyWith(isBusy: false, errorMessage: e.message),
      );
    } catch (_) {
      writeState(
        readState().copyWith(
          isBusy: false,
          errorMessage: 'Gagal memperbarui pengingat harian.',
        ),
      );
    }
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    final empty = await _loadHomeDashboard.execute();
    writeState(
      HomeDashboardUiState(
        isInitialized: true,
        summary: empty,
      ),
    );
  }
}
