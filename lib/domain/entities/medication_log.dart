import '../enums/medication_state.dart';
import '../enums/session_sync_status.dart';

/// Immutable patient or caregiver medication intake entry for ON/OFF Levodopa tracking.
class MedicationLog {
  const MedicationLog({
    required this.logId,
    required this.drugName,
    required this.dosageMg,
    required this.takenAtUtc,
    required this.medState,
    this.notes,
    this.syncStatus = SessionSyncStatus.localOnly,
  });

  final String logId;
  final String drugName;
  final double dosageMg;
  final DateTime takenAtUtc;
  final MedicationState medState;
  final String? notes;
  final SessionSyncStatus syncStatus;

  MedicationLog copyWith({
    String? logId,
    String? drugName,
    double? dosageMg,
    DateTime? takenAtUtc,
    MedicationState? medState,
    String? notes,
    bool clearNotes = false,
    SessionSyncStatus? syncStatus,
  }) {
    return MedicationLog(
      logId: logId ?? this.logId,
      drugName: drugName ?? this.drugName,
      dosageMg: dosageMg ?? this.dosageMg,
      takenAtUtc: takenAtUtc ?? this.takenAtUtc,
      medState: medState ?? this.medState,
      notes: clearNotes ? null : (notes ?? this.notes),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicationLog &&
        other.logId == logId &&
        other.drugName == drugName &&
        other.dosageMg == dosageMg &&
        other.takenAtUtc == takenAtUtc &&
        other.medState == medState &&
        other.notes == notes &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        logId,
        drugName,
        dosageMg,
        takenAtUtc,
        medState,
        notes,
        syncStatus,
      );
}
