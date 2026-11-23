import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/application/state_machines/clinical_session_fsm.dart';
import 'package:parkinstep/domain/entities/window_prediction_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_protocol.dart';
import 'package:parkinstep/domain/enums/session_stage.dart';

WindowPredictionItem _win(int idx, {required bool rawPositive}) {
  return WindowPredictionItem(
    windowIdx: idx,
    startSec: idx.toDouble(),
    endSec: idx + 2.0,
    rawProb: rawPositive ? 0.65 : 0.08,
    calibratedScore: rawPositive ? 76.4 : 15.4,
    predRaw: rawPositive,
    predPostprocessed: false,
    freezeIndexAnkle: rawPositive ? 2.4 : 0.4,
    bilateralAsymAnkle: 0.1,
  );
}

void main() {
  const fsm = ClinicalSessionFsm();

  group('ClinicalSessionFsm Video-Based Transitions & Min-Run Postprocessing', () {
    test('Countdown (3-2-1) -> 120s guided recording -> milestone voice cues -> auto-stop to reviewRecorded', () {
      var s = const ClinicalSessionFsmState(
        protocol: SessionProtocol.walkBackAndForth,
        medState: MedicationState.on,
      );
      expect(s.stage, SessionStage.readyToRecord);

      // Start 3-second countdown
      var step = fsm.requestStartCountdown(s);
      s = step.state;
      expect(s.stage, SessionStage.countdown);
      expect(s.countdownRemainingSec, 3);
      expect(step.effects, contains(SessionFsmEffect.playCountdownBeep));

      // Ticks 3 -> 2 -> 1
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.countdownRemainingSec, 2);
      expect(step.effects, contains(SessionFsmEffect.playCountdownBeep));

      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.countdownRemainingSec, 1);
      expect(step.effects, contains(SessionFsmEffect.playCountdownBeep));

      // Final countdown tick enters recordingActive and speaks 0s cue
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.stage, SessionStage.recordingActive);
      expect(s.elapsedSec, 0);
      expect(step.effects, contains(SessionFsmEffect.startVideoRecording));
      expect(step.effects, contains(SessionFsmEffect.speakCue));
      expect(s.effectiveCue.atSecond, 0);

      // Advance 1..119s and verify milestone speech at 30, 60, 90, 110
      final spokenMilestones = <int>[];
      for (var t = 1; t < 120; t++) {
        step = fsm.onOneSecondTick(s);
        s = step.state;
        expect(s.stage, SessionStage.recordingActive);
        expect(s.elapsedSec, t);
        if (step.effects.contains(SessionFsmEffect.speakCue)) {
          spokenMilestones.add(t);
        }
      }
      expect(spokenMilestones, <int>[30, 60, 90, 110]);
      expect(s.effectiveCue.atSecond, 110);

      // Tick 120 auto-stops recording into reviewRecorded
      step = fsm.onOneSecondTick(s);
      s = step.state;
      expect(s.stage, SessionStage.reviewRecorded);
      expect(s.recordedDurationSec, 120);
      expect(s.canSubmitVideo, isTrue);
      expect(step.effects, contains(SessionFsmEffect.stopVideoRecording));
      expect(step.effects, contains(SessionFsmEffect.stopVoice));
      expect(step.effects, contains(SessionFsmEffect.playCompletionChime));
    });

    test('Short < 3s recording blocks submission until retaken >= 3s', () {
      var s = const ClinicalSessionFsmState(
        protocol: SessionProtocol.sitToStand,
        stage: SessionStage.recordingActive,
        elapsedSec: 2,
      );

      var step = fsm.requestStopRecording(s);
      s = step.state;
      expect(s.stage, SessionStage.reviewRecorded);
      expect(s.recordedDurationSec, 2);
      expect(s.canSubmitVideo, isFalse);

      // Submit blocked under 3 seconds
      final blocked = fsm.requestSubmitVideo(s);
      expect(blocked.state.stage, SessionStage.reviewRecorded);
      expect(blocked.effects, isEmpty);

      // Retake returns cleanly to readyToRecord with temp video wipe effect
      step = fsm.requestRetake(s);
      s = step.state;
      expect(s.stage, SessionStage.readyToRecord);
      expect(step.effects, contains(SessionFsmEffect.deleteTempVideo));

      // Longer recording (5s) allows submit -> analyzingVideo
      s = s.copyWith(stage: SessionStage.recordingActive, elapsedSec: 5);
      s = fsm.requestStopRecording(s).state;
      s = fsm.attachRecordedVideoPath(s, '/tmp/test.mp4');
      expect(s.canSubmitVideo, isTrue);

      final submit = fsm.requestSubmitVideo(s);
      expect(submit.state.stage, SessionStage.analyzingVideo);
      expect(submit.effects, contains(SessionFsmEffect.beginVideoAnalysis));
    });

    test('applyMinRunPostProcessing filters isolated single-window spikes & groups confirmed episodes', () {
      final raw = <WindowPredictionItem>[
        _win(0, rawPositive: false),
        _win(1, rawPositive: true), // isolated 1-window spike -> suppressed
        _win(2, rawPositive: false),
        _win(3, rawPositive: true), // confirmed run length 3
        _win(4, rawPositive: true),
        _win(5, rawPositive: true),
        _win(6, rawPositive: false),
      ];

      final post = ClinicalSessionFsm.applyMinRunPostProcessing(raw, minRun: 2);
      expect(post.map((w) => w.predPostprocessed).toList(), <bool>[
        false,
        false,
        false,
        true,
        true,
        true,
        false,
      ]);

      final episodes = ClinicalSessionFsm.extractConfirmedEpisodes(post);
      expect(episodes, hasLength(1));
      expect(episodes.first.episodeIndex, 1);
      expect(episodes.first.startSec, 3.0);
      expect(episodes.first.endSec, 7.0);
      expect(episodes.first.durationSec, 4.0);
    });
  });
}
