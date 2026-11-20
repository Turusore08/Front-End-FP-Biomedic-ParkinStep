import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/application/controllers/metronome_coordinator.dart';
import 'package:parkinstep/application/controllers/metronome_ui_state.dart';
import 'package:parkinstep/application/controllers/pre_flight_coordinator.dart';
import 'package:parkinstep/application/controllers/pre_flight_ui_state.dart';
import 'package:parkinstep/application/ports/cueing_port.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';

class _SpyCueingPort implements CueingPort {
  final List<({bool accented, bool sound, bool haptic})> beats = [];
  int chimes = 0;

  @override
  Future<void> playMetronomeBeat({
    required bool accented,
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    beats.add((
      accented: accented,
      sound: soundEnabled,
      haptic: hapticEnabled,
    ));
  }

  @override
  Future<void> playCompletionChime({
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    chimes++;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.onFire, {required this.repeating});

  final Duration duration;
  final void Function() onFire;
  final bool repeating;
  int _ticks = 0;
  bool cancelled = false;

  void fire() {
    if (cancelled) return;
    _ticks++;
    if (!repeating) cancelled = true;
    onFire();
  }

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => _ticks;
}

void main() {
  group('PreFlightCoordinator & MetronomeCoordinator', () {
    test('PreFlightCoordinator gates confirmReady until 4/4 checked & seeds medState cleanly', () {
      var state = const PreFlightUiState();
      final fixedUtc = DateTime.utc(2026, 11, 20, 10, 0);
      final coordinator = PreFlightCoordinator(
        readState: () => state,
        writeState: (next) => state = next,
        clock: () => fixedUtc,
      );

      coordinator.seedMedStateIfUnconfirmed(MedicationState.off);
      expect(state.checklist.medState, MedicationState.off);

      expect(coordinator.confirmReady(), isFalse);
      expect(state.isConfirmed, isFalse);

      coordinator.toggleFloorSafe();
      coordinator.toggleSpaceClear();
      coordinator.toggleSupportReady();
      expect(coordinator.confirmReady(), isFalse);

      coordinator.toggleAttireAndFraming();
      coordinator.selectMedState(MedicationState.on);
      expect(coordinator.confirmReady(), isTrue);
      expect(state.isConfirmed, isTrue);
      expect(state.confirmedAtUtc, fixedUtc);

      coordinator.reset();
      expect(state.checklist.completedCount, 0);
      expect(state.isConfirmed, isFalse);
    });

    test('MetronomeCoordinator delivers accented beats, live BPM reschedule, mute flag, and completion chime', () {
      var state = const MetronomeUiState();
      final spyCue = _SpyCueingPort();
      final periodicTimers = <_FakeTimer>[];
      final oneShotTimers = <_FakeTimer>[];

      Timer fakePeriodic(Duration d, void Function(Timer) cb) {
        late final _FakeTimer fake;
        fake = _FakeTimer(
          d,
          () => cb(fake),
          repeating: true,
        );
        periodicTimers.add(fake);
        return fake;
      }

      Timer fakeOneShot(Duration d, void Function() cb) {
        final fake = _FakeTimer(d, cb, repeating: false);
        oneShotTimers.add(fake);
        return fake;
      }

      final coordinator = MetronomeCoordinator(
        cueingPort: spyCue,
        readState: () => state,
        writeState: (next) => state = next,
        periodicTimerFactory: fakePeriodic,
        oneShotTimerFactory: fakeOneShot,
      );

      // Select 1 minute while idle, ignored later while running
      coordinator.selectDuration(60);
      expect(state.remainingSeconds, 60);
      expect(state.displayedSteps, 80);

      coordinator.start();
      expect(state.isRunning, isTrue);
      // Beat #1 fires synchronously on start -> accented
      expect(state.beatCount, 1);
      expect(spyCue.beats.last.accented, isTrue);
      expect(spyCue.beats.last.sound, isTrue);
      expect(state.pulseVisualActive, isTrue);

      // Pulse one-shot clears visual pulse
      oneShotTimers.last.fire();
      expect(state.pulseVisualActive, isFalse);

      // Active duration selection is ignored while running
      coordinator.selectDuration(300);
      expect(state.config.durationSeconds, 60);

      // Beat periodic timer is periodicTimers[0]; second countdown timer is periodicTimers[1]
      final beatTimerInitial = periodicTimers[0];
      final secondTimer = periodicTimers[1];

      // Fire beats 2, 3, 4 (unaccented) and beat 5 (accented)
      beatTimerInitial.fire();
      beatTimerInitial.fire();
      beatTimerInitial.fire();
      beatTimerInitial.fire();
      expect(state.beatCount, 5);
      expect(spyCue.beats[1].accented, isFalse);
      expect(spyCue.beats[2].accented, isFalse);
      expect(spyCue.beats[3].accented, isFalse);
      expect(spyCue.beats[4].accented, isTrue);

      // Live BPM adjustment reschedules beat timer immediately without stopping
      coordinator.incrementBpm();
      expect(state.config.bpm, 85);
      expect(beatTimerInitial.cancelled, isTrue);
      final beatTimerRescheduled = periodicTimers.last;
      expect(beatTimerRescheduled.cancelled, isFalse);

      // Sound mute is reflected on next beat
      coordinator.toggleSound();
      beatTimerRescheduled.fire();
      expect(spyCue.beats.last.sound, isFalse);

      // Advance remaining seconds down to completion
      for (var i = 0; i < 60; i++) {
        secondTimer.fire();
      }
      expect(state.runState, MetronomeRunState.completed);
      expect(state.remainingSeconds, 0);
      expect(spyCue.chimes, 1);
      expect(beatTimerRescheduled.cancelled, isTrue);
      expect(secondTimer.cancelled, isTrue);
    });
  });
}
