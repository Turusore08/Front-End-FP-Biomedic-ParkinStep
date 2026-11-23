import '../../domain/entities/completed_session_record.dart';
import '../state_machines/clinical_session_fsm.dart';

/// Immutable UI snapshot combining video ClinicalSessionFsmState with lifecycle & summary state.
class ClinicalSessionUiState {
  const ClinicalSessionUiState({
    this.fsm = const ClinicalSessionFsmState(),
    this.isPreviewSimulation = true,
    this.isOpeningCamera = false,
    this.isFinalizingVideoFile = false,
    this.completedRecord,
    this.errorMessage,
    this.isPausedByLifecycle = false,
  });

  final ClinicalSessionFsmState fsm;
  final bool isPreviewSimulation;
  final bool isOpeningCamera;
  final bool isFinalizingVideoFile;
  final CompletedSessionRecord? completedRecord;
  final String? errorMessage;
  final bool isPausedByLifecycle;

  ClinicalSessionUiState copyWith({
    ClinicalSessionFsmState? fsm,
    bool? isPreviewSimulation,
    bool? isOpeningCamera,
    bool? isFinalizingVideoFile,
    CompletedSessionRecord? completedRecord,
    bool clearCompletedRecord = false,
    String? errorMessage,
    bool clearError = false,
    bool? isPausedByLifecycle,
  }) {
    return ClinicalSessionUiState(
      fsm: fsm ?? this.fsm,
      isPreviewSimulation: isPreviewSimulation ?? this.isPreviewSimulation,
      isOpeningCamera: isOpeningCamera ?? this.isOpeningCamera,
      isFinalizingVideoFile:
          isFinalizingVideoFile ?? this.isFinalizingVideoFile,
      completedRecord: clearCompletedRecord
          ? null
          : (completedRecord ?? this.completedRecord),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPausedByLifecycle: isPausedByLifecycle ?? this.isPausedByLifecycle,
    );
  }
}
