import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/entities/metronome_config.dart';
import 'package:parkinstep/domain/entities/pre_flight_checklist.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_protocol.dart';

void main() {
  group('PreFlightChecklist, SessionProtocol & MetronomeConfig Domain Entities', () {
    test('PreFlightChecklist tracks protocol, completed count, gate condition, and equality', () {
      const initial = PreFlightChecklist();
      expect(initial.protocol, SessionProtocol.turning360);
      expect(initial.completedCount, 0);
      expect(initial.isAllChecked, isFalse);
      expect(initial.medState, MedicationState.unknown);

      final partial = initial.copyWith(
        protocol: SessionProtocol.sitToStand,
        floorSafe: true,
        spaceClear: true,
      );
      expect(partial.protocol, SessionProtocol.sitToStand);
      expect(partial.completedCount, 2);
      expect(partial.isAllChecked, isFalse);

      final fullA = partial.copyWith(
        supportReady: true,
        attireAndFraming: true,
        medState: MedicationState.on,
      );
      final fullB = partial.copyWith(
        supportReady: true,
        attireAndFraming: true,
        medState: MedicationState.on,
      );

      expect(fullA.completedCount, 4);
      expect(fullA.isAllChecked, isTrue);
      expect(fullA, equals(fullB));
      expect(fullA.hashCode, equals(fullB.hashCode));
    });

    test('SessionProtocol maps storage values and exposes timed Indonesian cues', () {
      expect(
        SessionProtocol.fromStorageValue('TURNING_360_2MIN'),
        SessionProtocol.turning360,
      );
      expect(
        SessionProtocol.fromStorageValue('WALK_BACK_AND_FORTH_2MIN'),
        SessionProtocol.walkBackAndForth,
      );
      expect(
        SessionProtocol.fromStorageValue('FREE_WALK_MONITORING'),
        SessionProtocol.walkBackAndForth,
      );
      expect(
        SessionProtocol.fromStorageValue('SIT_TO_STAND_2MIN'),
        SessionProtocol.sitToStand,
      );
      expect(SessionProtocol.fromStorageValue(null), SessionProtocol.turning360);

      for (final protocol in SessionProtocol.values) {
        expect(protocol.durationSec, 120);
        expect(protocol.timedCues.length, 5);
        expect(protocol.milestoneAt(0), isNotNull);
        expect(protocol.milestoneAt(30), isNotNull);
        expect(protocol.milestoneAt(60), isNotNull);
        expect(protocol.milestoneAt(90), isNotNull);
        expect(protocol.milestoneAt(110), isNotNull);
        expect(protocol.milestoneAt(15), isNull);
        expect(
          protocol.cueForElapsed(35).highlightWord,
          protocol.timedCues[1].highlightWord,
        );
      }
    });

    test('MetronomeConfig enforces 40..120 BPM clamping and computes interval/steps', () {
      const defaults = MetronomeConfig();
      expect(defaults.bpm, 80);
      expect(defaults.durationSeconds, 120);
      expect(defaults.estimatedSteps, 160);
      expect(defaults.beatInterval, const Duration(milliseconds: 750));

      final minClamped = defaults.stepBpm(-100);
      expect(minClamped.bpm, MetronomeConfig.minBpm);
      expect(minClamped.beatInterval, const Duration(milliseconds: 1500));

      final maxClamped = defaults.stepBpm(100);
      expect(maxClamped.bpm, MetronomeConfig.maxBpm);
      expect(maxClamped.beatInterval, const Duration(milliseconds: 500));
      expect(maxClamped.copyWith(durationSeconds: 60).estimatedSteps, 120);
    });
  });
}
