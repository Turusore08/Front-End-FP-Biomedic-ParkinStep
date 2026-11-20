import '../../domain/enums/medication_state.dart';
import 'pre_flight_ui_state.dart';

/// Pure Dart coordinator governing S-04 safety checklist completion and gating.
class PreFlightCoordinator {
  PreFlightCoordinator({
    required this.readState,
    required this.writeState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PreFlightUiState Function() readState;
  final void Function(PreFlightUiState next) writeState;
  final DateTime Function() _clock;

  void toggleFloorSafe() {
    final current = readState();
    writeState(
      current.copyWith(
        checklist: current.checklist.copyWith(
          floorSafe: !current.checklist.floorSafe,
        ),
        isConfirmed: false,
        clearConfirmedAt: true,
      ),
    );
  }

  void toggleSpaceClear() {
    final current = readState();
    writeState(
      current.copyWith(
        checklist: current.checklist.copyWith(
          spaceClear: !current.checklist.spaceClear,
        ),
        isConfirmed: false,
        clearConfirmedAt: true,
      ),
    );
  }

  void toggleSupportReady() {
    final current = readState();
    writeState(
      current.copyWith(
        checklist: current.checklist.copyWith(
          supportReady: !current.checklist.supportReady,
        ),
        isConfirmed: false,
        clearConfirmedAt: true,
      ),
    );
  }

  void toggleAttireAndFraming() {
    final current = readState();
    writeState(
      current.copyWith(
        checklist: current.checklist.copyWith(
          attireAndFraming: !current.checklist.attireAndFraming,
        ),
        isConfirmed: false,
        clearConfirmedAt: true,
      ),
    );
  }

  void selectMedState(MedicationState medState) {
    final current = readState();
    writeState(
      current.copyWith(
        checklist: current.checklist.copyWith(medState: medState),
        isConfirmed: false,
        clearConfirmedAt: true,
      ),
    );
  }

  void seedMedStateIfUnconfirmed(MedicationState medState) {
    final current = readState();
    if (!current.isConfirmed &&
        current.checklist.medState == MedicationState.unknown &&
        medState != MedicationState.unknown) {
      writeState(
        current.copyWith(
          checklist: current.checklist.copyWith(medState: medState),
        ),
      );
    }
  }

  /// Returns true only when all 4 physical safety checks are checked.
  bool confirmReady() {
    final current = readState();
    if (!current.checklist.isAllChecked) {
      return false;
    }
    writeState(
      current.copyWith(
        isConfirmed: true,
        confirmedAtUtc: _clock().toUtc(),
      ),
    );
    return true;
  }

  void reset() {
    writeState(const PreFlightUiState());
  }
}
