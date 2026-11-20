import '../../domain/entities/home_dashboard_summary.dart';
import '../../domain/entities/medication_log.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/errors/dashboard_failure.dart';
import '../ports/home_dashboard_repository_port.dart';

/// Validates and records a medication intake entry with ON/OFF state.
class LogMedicationIntake {
  LogMedicationIntake(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HomeDashboardRepositoryPort _repository;
  final DateTime Function() _clock;

  Future<HomeDashboardSummary> execute({
    required String drugName,
    required double dosageMg,
    required MedicationState medState,
    String? notes,
  }) async {
    final trimmedDrug = drugName.trim();
    if (trimmedDrug.isEmpty || trimmedDrug.length > 80) {
      throw const InvalidDrugNameFailure();
    }
    if (!dosageMg.isFinite || dosageMg <= 0 || dosageMg > 2000) {
      throw const InvalidDosageFailure();
    }

    final trimmedNotes = notes?.trim();
    final nowUtc = _clock().toUtc();
    final log = MedicationLog(
      logId: 'med_${nowUtc.microsecondsSinceEpoch}',
      drugName: trimmedDrug,
      dosageMg: dosageMg,
      takenAtUtc: nowUtc,
      medState: medState,
      notes: (trimmedNotes == null || trimmedNotes.isEmpty)
          ? null
          : trimmedNotes,
    );
    return _repository.addMedicationLog(log);
  }
}
