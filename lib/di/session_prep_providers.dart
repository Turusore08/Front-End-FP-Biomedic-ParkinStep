import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/controllers/metronome_coordinator.dart';
import '../application/controllers/metronome_ui_state.dart';
import '../application/controllers/pre_flight_coordinator.dart';
import '../application/controllers/pre_flight_ui_state.dart';
import '../application/ports/cueing_port.dart';
import '../domain/enums/medication_state.dart';
import '../infrastructure/cueing/system_cueing_adapter.dart';

final cueingPortProvider = Provider<CueingPort>(
  (ref) => const SystemCueingAdapter(),
);

/// Riverpod 3 Notifier binding pure-Dart PreFlightCoordinator to S-04 UI.
class PreFlightController extends Notifier<PreFlightUiState> {
  late PreFlightCoordinator _coordinator;

  @override
  PreFlightUiState build() {
    _coordinator = PreFlightCoordinator(
      readState: () => state,
      writeState: (next) => state = next,
    );
    return const PreFlightUiState();
  }

  void toggleFloorSafe() => _coordinator.toggleFloorSafe();

  void toggleSpaceClear() => _coordinator.toggleSpaceClear();

  void toggleSupportReady() => _coordinator.toggleSupportReady();

  void toggleAttireAndFraming() => _coordinator.toggleAttireAndFraming();

  void selectMedState(MedicationState medState) =>
      _coordinator.selectMedState(medState);

  void seedMedStateIfUnconfirmed(MedicationState medState) =>
      _coordinator.seedMedStateIfUnconfirmed(medState);

  bool confirmReady() => _coordinator.confirmReady();

  void reset() => _coordinator.reset();
}

final preFlightControllerProvider =
    NotifierProvider<PreFlightController, PreFlightUiState>(
  PreFlightController.new,
);

/// Riverpod 3 Notifier binding pure-Dart MetronomeCoordinator to S-07 UI.
class MetronomeController extends Notifier<MetronomeUiState> {
  late MetronomeCoordinator _coordinator;

  @override
  MetronomeUiState build() {
    _coordinator = MetronomeCoordinator(
      cueingPort: ref.read(cueingPortProvider),
      readState: () => state,
      writeState: (next) => state = next,
    );
    ref.onDispose(_coordinator.cancelTimersOnly);
    return const MetronomeUiState();
  }

  void incrementBpm() => _coordinator.incrementBpm();

  void decrementBpm() => _coordinator.decrementBpm();

  void selectDuration(int seconds) => _coordinator.selectDuration(seconds);

  void toggleSound() => _coordinator.toggleSound();

  void start() => _coordinator.start();

  void stop() => _coordinator.stop();

  void reset() => _coordinator.reset();

  void cancelTimersOnly() => _coordinator.cancelTimersOnly();
}

final metronomeControllerProvider =
    NotifierProvider<MetronomeController, MetronomeUiState>(
  MetronomeController.new,
);
