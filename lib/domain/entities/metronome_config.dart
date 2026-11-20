/// Immutable Rhythmic Auditory Stimulation (RAS) metronome configuration.
class MetronomeConfig {
  const MetronomeConfig({
    this.bpm = defaultBpm,
    this.durationSeconds = defaultDurationSec,
    this.soundEnabled = true,
    this.hapticEnabled = true,
  });

  static const int minBpm = 40;
  static const int maxBpm = 120;
  static const int defaultBpm = 80;
  static const int bpmStep = 5;
  static const int defaultDurationSec = 120;
  static const List<int> allowedDurationsSec = <int>[60, 120, 300];

  final int bpm;
  final int durationSeconds;
  final bool soundEnabled;
  final bool hapticEnabled;

  Duration get beatInterval => Duration(microseconds: (60000000 / bpm).round());

  int get estimatedSteps => (bpm * durationSeconds / 60).round();

  MetronomeConfig stepBpm(int delta) {
    final nextBpm = (bpm + delta).clamp(minBpm, maxBpm);
    return copyWith(bpm: nextBpm);
  }

  MetronomeConfig copyWith({
    int? bpm,
    int? durationSeconds,
    bool? soundEnabled,
    bool? hapticEnabled,
  }) {
    return MetronomeConfig(
      bpm: bpm ?? this.bpm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MetronomeConfig &&
        other.bpm == bpm &&
        other.durationSeconds == durationSeconds &&
        other.soundEnabled == soundEnabled &&
        other.hapticEnabled == hapticEnabled;
  }

  @override
  int get hashCode =>
      Object.hash(bpm, durationSeconds, soundEnabled, hapticEnabled);
}
