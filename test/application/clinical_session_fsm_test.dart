import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/application/state_machines/clinical_session_fsm.dart';
import 'package:parkinstep/domain/entities/live_frame_result.dart';
import 'package:parkinstep/domain/enums/alert_tier.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_stage.dart';
import 'package:parkinstep/domain/value_objects/keypoint_2d.dart';

LiveFrameResult _frame({
  int seq = 1,
  double lb6Conf = 0.90,
  double rawProb = 0.08,
  double hipDropRatio = 0.0,
  bool isImmobile = false,
}) {
  return LiveFrameResult(
    sequenceId: seq,
    timestampMs: seq * 66,
    imageWidth: 480,
    imageHeight: 640,
    keypoints17: List<Keypoint2D>.filled(
      17,
      Keypoint2D(x: 240, y: 320, conf: lb6Conf),
    ),
    lb6AvgConf: lb6Conf,
    effectiveFps: 15.0,
    rawProb: rawProb,
    freezeIndex: rawProb >= 0.26 ? 2.41 : 0.40,
    hipDropRatio: hipDropRatio,
    isImmobile: isImmobile,
  );
}

void main() {
  const fsm = ClinicalSessionFsm();

  group('ClinicalSessionFsm Deterministic Transitions', () {
    test('Low light > 3s shows error card & retryCalibration recovers cleanly through calibration into recording', () {
      var s = const ClinicalSessionFsmState(medState: MedicationState.on);
      s = fsm.onLiveFrame(s, _frame(lb6Conf: 0.10)).state;

      // 4 bad 1-second ticks (> 3s continuous LB6 < 0.20) trigger low-light error
      for (var i = 0; i < 4; i++) {
        s = fsm.onOneSecondTick(s).state;
      }
      expect(s.showLowLightError, isTrue);
      expect(s.stage, SessionStage.framingCheck);

      // Retry resets error & accepts good LB6 frames -> 2s framing lock -> 3s calibration -> recordingActive
      s = fsm.retryCalibration(s).state;
      expect(s.showLowLightError, isFalse);

      s = fsm.onLiveFrame(s, _frame(seq: 2, lb6Conf: 0.92)).state;
      s = fsm.onOneSecondTick(s).state;
      expect(s.stage, SessionStage.framingCheck);
      s = fsm.onOneSecondTick(s).state;
      expect(s.stage, SessionStage.calibratingStanding);
      expect(s.calibrationRemainingSec, 3);

      for (var i = 0; i < 3; i++) {
        s = fsm.onOneSecondTick(s).state;
      }
      expect(s.stage, SessionStage.recordingActive);
      expect(s.alertTier, AlertTier.gaitNormal);
    });

    test('Two-Tier Alert enforces min_run=2 confirmation and 2-window recovery hysteresis', () {
      var s = const ClinicalSessionFsmState(
        stage: SessionStage.recordingActive,
        medState: MedicationState.off,
      );

      // Single positive window -> EARLY_WARNING only (no full metronome cueing yet)
      s = fsm.onLiveFrame(s, _frame(rawProb: 0.65)).state;
      var step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.alertTier, AlertTier.earlyWarning);
      expect(step.effects, contains(SessionFsmEffect.playEarlyWarningChime));
      expect(step.effects, isNot(contains(SessionFsmEffect.startFogCueing)));

      // Second consecutive positive window -> FOG_CONFIRMED & starts metronome cueing
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.alertTier, AlertTier.fogConfirmed);
      expect(s.episodeCount, 1);
      expect(s.confirmedFogWindowCount, 2);
      expect(step.effects, contains(SessionFsmEffect.startFogCueing));

      // First normal window keeps FOG_CONFIRMED (hysteresis prevents flicker)
      s = fsm.onLiveFrame(s, _frame(seq: 2, rawProb: 0.05)).state;
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.alertTier, AlertTier.fogConfirmed);
      expect(step.effects, isEmpty);

      // Second consecutive normal window returns to GAIT_NORMAL & stops cueing
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.alertTier, AlertTier.gaitNormal);
      expect(step.effects, contains(SessionFsmEffect.stopFogCueing));
    });

    test('Prolonged freeze > 15s opens Fall Guard and Im OK cancels cleanly as false alarm', () {
      var s = const ClinicalSessionFsmState(stage: SessionStage.recordingActive);
      s = fsm.onLiveFrame(s, _frame(rawProb: 0.70)).state;

      // Windows 1..15 remain in recordingActive; window 16 (> 15s) triggers Fall Guard
      for (var i = 0; i < 15; i++) {
        s = fsm.onOneSecondTick(s).state;
        expect(s.stage, SessionStage.recordingActive);
      }

      final triggerStep = fsm.onOneSecondTick(s);
      s = triggerStep.state;
      expect(s.stage, SessionStage.fallGuardActive);
      expect(s.alertTier, AlertTier.fallGuard);
      expect(s.fallCountdownSec, 10);
      expect(triggerStep.effects, contains(SessionFsmEffect.startFallGuardAlarm));

      // Cancelling within 10s logs false alarm & resumes normal gait monitoring
      final cancelStep = fsm.cancelFallGuard(s);
      s = cancelStep.state;
      expect(s.stage, SessionStage.recordingActive);
      expect(s.alertTier, AlertTier.gaitNormal);
      expect(s.fallGuardFalseAlarms, 1);
      expect(cancelStep.effects, contains(SessionFsmEffect.stopFallGuardAlarm));
    });

    test('Sudden hip drop >= 0.65 & immobile >= 3s triggers Fall Guard -> 10s expiry dispatches alert', () {
      var s = const ClinicalSessionFsmState(stage: SessionStage.recordingActive);
      s = fsm
          .onLiveFrame(s, _frame(hipDropRatio: 0.78, isImmobile: true))
          .state;

      s = fsm.onOneSecondTick(s).state;
      s = fsm.onOneSecondTick(s).state;
      expect(s.stage, SessionStage.recordingActive);

      // 3rd second triggers Fall Guard
      s = fsm.onOneSecondTick(s).state;
      expect(s.stage, SessionStage.fallGuardActive);

      // Count down 10 seconds to 0 -> emergencyDispatched
      late ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects}) last;
      for (var i = 0; i < 10; i++) {
        last = fsm.onOneSecondTick(s);
        s = last.state;
      }
      expect(s.stage, SessionStage.emergencyDispatched);
      expect(s.fallCountdownSec, 0);
      expect(last.effects, contains(SessionFsmEffect.dispatchEmergencyAlert));

      // Manual finish moves to postSessionAnalyzing
      final finishStep = fsm.requestManualFinish(s);
      expect(finishStep.state.stage, SessionStage.postSessionAnalyzing);
      expect(
        finishStep.effects,
        contains(SessionFsmEffect.beginPostSessionAnalysis),
      );
    });
  });
}
