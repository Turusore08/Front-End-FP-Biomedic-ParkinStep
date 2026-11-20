import 'dart:async';

import '../../domain/entities/metronome_config.dart';
import '../ports/cueing_port.dart';
import 'metronome_ui_state.dart';

typedef PeriodicTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);

typedef OneShotTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Pure Dart coordinator orchestrating the S-07 RAS Metronome countdown,
/// live BPM stepping, acoustic/haptic beat delivery, and safe timer cleanup.
class MetronomeCoordinator {
  MetronomeCoordinator({
    required this.cueingPort,
    required this.readState,
    required this.writeState,
    PeriodicTimerFactory? periodicTimerFactory,
    OneShotTimerFactory? oneShotTimerFactory,
  })  : _periodicTimerFactory = periodicTimerFactory ?? Timer.periodic,
        _oneShotTimerFactory = oneShotTimerFactory ?? Timer.new;

  final CueingPort cueingPort;
  final MetronomeUiState Function() readState;
  final void Function(MetronomeUiState next) writeState;
  final PeriodicTimerFactory _periodicTimerFactory;
  final OneShotTimerFactory _oneShotTimerFactory;

  Timer? _secondTimer;
  Timer? _beatTimer;
  Timer? _pulseTimer;

  void incrementBpm() => _stepBpm(MetronomeConfig.bpmStep);

  void decrementBpm() => _stepBpm(-MetronomeConfig.bpmStep);

  void _stepBpm(int delta) {
    final current = readState();
    final nextConfig = current.config.stepBpm(delta);
    if (nextConfig == current.config) return;

    writeState(current.copyWith(config: nextConfig));
    if (current.isRunning) {
      _beatTimer?.cancel();
      _beatTimer = _periodicTimerFactory(
        nextConfig.beatInterval,
        (_) => _triggerBeat(),
      );
    }
  }

  void selectDuration(int seconds) {
    final current = readState();
    if (current.isRunning) return;
    if (!MetronomeConfig.allowedDurationsSec.contains(seconds)) return;

    writeState(
      current.copyWith(
        config: current.config.copyWith(durationSeconds: seconds),
        runState: MetronomeRunState.idle,
        remainingSeconds: seconds,
        beatCount: 0,
        pulseVisualActive: false,
      ),
    );
  }

  void toggleSound() {
    final current = readState();
    writeState(
      current.copyWith(
        config: current.config.copyWith(
          soundEnabled: !current.config.soundEnabled,
        ),
      ),
    );
  }

  void start() {
    final current = readState();
    if (current.isRunning) return;

    cancelTimersOnly();
    final restartFromFull = current.remainingSeconds <= 0 ||
        current.runState == MetronomeRunState.completed;
    final startSeconds = restartFromFull
        ? current.config.durationSeconds
        : current.remainingSeconds;
    final startBeats = restartFromFull ? 0 : current.beatCount;

    writeState(
      current.copyWith(
        runState: MetronomeRunState.running,
        remainingSeconds: startSeconds,
        beatCount: startBeats,
        pulseVisualActive: false,
      ),
    );

    _triggerBeat();
    _beatTimer = _periodicTimerFactory(
      current.config.beatInterval,
      (_) => _triggerBeat(),
    );
    _secondTimer = _periodicTimerFactory(
      const Duration(seconds: 1),
      (_) => _onSecondTick(),
    );
  }

  void stop() {
    cancelTimersOnly();
    final current = readState();
    if (current.runState == MetronomeRunState.running) {
      writeState(
        current.copyWith(
          runState: MetronomeRunState.paused,
          pulseVisualActive: false,
        ),
      );
    }
  }

  void reset() {
    cancelTimersOnly();
    final current = readState();
    writeState(
      current.copyWith(
        runState: MetronomeRunState.idle,
        remainingSeconds: current.config.durationSeconds,
        beatCount: 0,
        pulseVisualActive: false,
      ),
    );
  }

  /// Cancels active timers without mutating Riverpod state during teardown/dispose.
  void cancelTimersOnly() {
    _secondTimer?.cancel();
    _secondTimer = null;
    _beatTimer?.cancel();
    _beatTimer = null;
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  void _triggerBeat() {
    final current = readState();
    if (!current.isRunning) return;

    final nextBeat = current.beatCount + 1;
    final isAccented = (nextBeat - 1) % 4 == 0;
    writeState(
      current.copyWith(
        beatCount: nextBeat,
        pulseVisualActive: true,
      ),
    );

    unawaited(
      cueingPort.playMetronomeBeat(
        accented: isAccented,
        soundEnabled: current.config.soundEnabled,
        hapticEnabled: current.config.hapticEnabled,
      ),
    );

    _pulseTimer?.cancel();
    _pulseTimer = _oneShotTimerFactory(
      const Duration(milliseconds: 120),
      () {
        final latest = readState();
        if (latest.isRunning && latest.pulseVisualActive) {
          writeState(latest.copyWith(pulseVisualActive: false));
        }
      },
    );
  }

  void _onSecondTick() {
    final current = readState();
    if (!current.isRunning) return;

    final nextRemaining = current.remainingSeconds - 1;
    if (nextRemaining <= 0) {
      cancelTimersOnly();
      writeState(
        current.copyWith(
          runState: MetronomeRunState.completed,
          remainingSeconds: 0,
          pulseVisualActive: false,
        ),
      );
      unawaited(
        cueingPort.playCompletionChime(
          soundEnabled: current.config.soundEnabled,
          hapticEnabled: current.config.hapticEnabled,
        ),
      );
      return;
    }

    writeState(current.copyWith(remainingSeconds: nextRemaining));
  }
}
