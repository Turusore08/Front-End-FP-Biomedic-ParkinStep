import '../../domain/entities/metronome_config.dart';

enum MetronomeRunState { idle, running, paused, completed }

/// Immutable UI snapshot for S-07 standalone RAS Metronome screen.
class MetronomeUiState {
  const MetronomeUiState({
    this.config = const MetronomeConfig(),
    this.runState = MetronomeRunState.idle,
    this.remainingSeconds = MetronomeConfig.defaultDurationSec,
    this.beatCount = 0,
    this.pulseVisualActive = false,
  });

  final MetronomeConfig config;
  final MetronomeRunState runState;
  final int remainingSeconds;
  final int beatCount;
  final bool pulseVisualActive;

  bool get isRunning => runState == MetronomeRunState.running;

  String get formattedRemainingTime {
    final safeSeconds = remainingSeconds < 0 ? 0 : remainingSeconds;
    final mins = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  int get displayedSteps =>
      runState == MetronomeRunState.idle ? config.estimatedSteps : beatCount;

  MetronomeUiState copyWith({
    MetronomeConfig? config,
    MetronomeRunState? runState,
    int? remainingSeconds,
    int? beatCount,
    bool? pulseVisualActive,
  }) {
    return MetronomeUiState(
      config: config ?? this.config,
      runState: runState ?? this.runState,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      beatCount: beatCount ?? this.beatCount,
      pulseVisualActive: pulseVisualActive ?? this.pulseVisualActive,
    );
  }
}
