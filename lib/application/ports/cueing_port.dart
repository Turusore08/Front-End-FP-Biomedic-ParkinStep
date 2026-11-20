/// Output gateway for acoustic and haptic Rhythmic Auditory Stimulation (RAS) cues.
abstract interface class CueingPort {
  Future<void> playMetronomeBeat({
    required bool accented,
    required bool soundEnabled,
    required bool hapticEnabled,
  });

  Future<void> playCompletionChime({
    required bool soundEnabled,
    required bool hapticEnabled,
  });
}
