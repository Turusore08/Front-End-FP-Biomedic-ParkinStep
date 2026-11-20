import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/entities/metronome_config.dart';
import 'package:parkinstep/domain/entities/pre_flight_checklist.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';

void main() {
  group('PreFlightChecklist & MetronomeConfig Domain Entities', () {
    test('PreFlightChecklist tracks completed count, gate condition, and equality', () {
      const initial = PreFlightChecklist();
      expect(initial.completedCount, 0);
      expect(initial.isAllChecked, isFalse);
      expect(initial.medState, MedicationState.unknown);

      final partial = initial.copyWith(floorSafe: true, spaceClear: true);
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
