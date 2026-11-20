import 'package:flutter/services.dart';

import '../../application/ports/cueing_port.dart';

/// Platform sound & haptic delivery adapter for standalone RAS Metronome beats.
class SystemCueingAdapter implements CueingPort {
  const SystemCueingAdapter();

  @override
  Future<void> playMetronomeBeat({
    required bool accented,
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    if (soundEnabled) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    if (hapticEnabled) {
      try {
        await (accented
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.mediumImpact());
      } catch (_) {}
    }
  }

  @override
  Future<void> playCompletionChime({
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    if (soundEnabled) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    if (hapticEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }
}
