import '../../domain/entities/pre_flight_checklist.dart';

/// Immutable UI snapshot for S-04 Pre-Flight Safety Checklist screen.
class PreFlightUiState {
  const PreFlightUiState({
    this.checklist = const PreFlightChecklist(),
    this.isConfirmed = false,
    this.confirmedAtUtc,
  });

  final PreFlightChecklist checklist;
  final bool isConfirmed;
  final DateTime? confirmedAtUtc;

  PreFlightUiState copyWith({
    PreFlightChecklist? checklist,
    bool? isConfirmed,
    DateTime? confirmedAtUtc,
    bool clearConfirmedAt = false,
  }) {
    return PreFlightUiState(
      checklist: checklist ?? this.checklist,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAtUtc:
          clearConfirmedAt ? null : (confirmedAtUtc ?? this.confirmedAtUtc),
    );
  }
}
