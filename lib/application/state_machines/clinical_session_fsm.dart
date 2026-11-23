import 'dart:math' as math;

import '../../domain/entities/fog_episode_item.dart';
import '../../domain/entities/window_prediction_item.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/session_protocol.dart';
import '../../domain/enums/session_stage.dart';

/// Side effects emitted deterministically by ClinicalSessionFsm transitions.
enum SessionFsmEffect {
  playCountdownBeep,
  speakCue,
  stopVoice,
  startVideoRecording,
  stopVideoRecording,
  playCompletionChime,
  deleteTempVideo,
  beginVideoAnalysis,
}

/// Immutable state snapshot governed by ClinicalSessionFsm.
class ClinicalSessionFsmState {
  const ClinicalSessionFsmState({
    this.protocol = SessionProtocol.turning360,
    this.stage = SessionStage.readyToRecord,
    this.medState = MedicationState.unknown,
    this.countdownRemainingSec = ClinicalSessionFsm.countdownDurationSec,
    this.elapsedSec = 0,
    this.recordedDurationSec = 0,
    this.recordedVideoPath,
    this.soundEnabled = true,
    this.activeCue,
    this.analysisProgress,
    this.analysisProcessedFrames = 0,
    this.analysisTotalFrames = 0,
    this.analysisStageLabel = '',
  });

  final SessionProtocol protocol;
  final SessionStage stage;
  final MedicationState medState;
  final int countdownRemainingSec;
  final int elapsedSec;
  final int recordedDurationSec;
  final String? recordedVideoPath;
  final bool soundEnabled;
  final ProtocolCueStep? activeCue;
  final double? analysisProgress;
  final int analysisProcessedFrames;
  final int analysisTotalFrames;
  final String analysisStageLabel;

  ProtocolCueStep get effectiveCue =>
      activeCue ?? protocol.cueForElapsed(elapsedSec);

  bool get canSubmitVideo =>
      recordedDurationSec >= ClinicalSessionFsm.minSubmittableDurationSec;

  ClinicalSessionFsmState copyWith({
    SessionProtocol? protocol,
    SessionStage? stage,
    MedicationState? medState,
    int? countdownRemainingSec,
    int? elapsedSec,
    int? recordedDurationSec,
    String? recordedVideoPath,
    bool clearVideoPath = false,
    bool? soundEnabled,
    ProtocolCueStep? activeCue,
    double? analysisProgress,
    bool clearAnalysisProgress = false,
    int? analysisProcessedFrames,
    int? analysisTotalFrames,
    String? analysisStageLabel,
  }) {
    return ClinicalSessionFsmState(
      protocol: protocol ?? this.protocol,
      stage: stage ?? this.stage,
      medState: medState ?? this.medState,
      countdownRemainingSec:
          countdownRemainingSec ?? this.countdownRemainingSec,
      elapsedSec: elapsedSec ?? this.elapsedSec,
      recordedDurationSec: recordedDurationSec ?? this.recordedDurationSec,
      recordedVideoPath: clearVideoPath
          ? null
          : (recordedVideoPath ?? this.recordedVideoPath),
      soundEnabled: soundEnabled ?? this.soundEnabled,
      activeCue: activeCue ?? this.activeCue,
      analysisProgress: clearAnalysisProgress
          ? null
          : (analysisProgress ?? this.analysisProgress),
      analysisProcessedFrames:
          analysisProcessedFrames ?? this.analysisProcessedFrames,
      analysisTotalFrames: analysisTotalFrames ?? this.analysisTotalFrames,
      analysisStageLabel: analysisStageLabel ?? this.analysisStageLabel,
    );
  }
}

/// Pure deterministic Finite State Machine for video-based gait test capture:
/// readyToRecord -> countdown (3-2-1) -> recordingActive (120s guided) ->
/// reviewRecorded (Ulangi / Kirim) -> analyzingVideo -> summaryReady.
class ClinicalSessionFsm {
  const ClinicalSessionFsm();

  static const int sessionDurationSec = 120;
  static const int countdownDurationSec = 3;
  static const int minSubmittableDurationSec = 3;
  static const int minRunWindows = 2;

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      requestStartCountdown(ClinicalSessionFsmState current) {
    if (current.stage != SessionStage.readyToRecord) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.countdown,
        countdownRemainingSec: countdownDurationSec,
        elapsedSec: 0,
        recordedDurationSec: 0,
        clearVideoPath: true,
        activeCue: current.protocol.cueForElapsed(0),
      ),
      effects: const <SessionFsmEffect>[SessionFsmEffect.playCountdownBeep],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      onOneSecondTick(ClinicalSessionFsmState current) {
    switch (current.stage) {
      case SessionStage.countdown:
        return _tickCountdown(current);
      case SessionStage.recordingActive:
        return _tickRecording(current);
      case SessionStage.readyToRecord:
      case SessionStage.reviewRecorded:
      case SessionStage.analyzingVideo:
      case SessionStage.summaryReady:
        return (state: current, effects: const <SessionFsmEffect>[]);
    }
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickCountdown(ClinicalSessionFsmState current) {
    final nextRem = current.countdownRemainingSec - 1;
    if (nextRem > 0) {
      return (
        state: current.copyWith(countdownRemainingSec: nextRem),
        effects: const <SessionFsmEffect>[SessionFsmEffect.playCountdownBeep],
      );
    }
    return (
      state: current.copyWith(
        stage: SessionStage.recordingActive,
        countdownRemainingSec: 0,
        elapsedSec: 0,
        activeCue: current.protocol.cueForElapsed(0),
      ),
      effects: const <SessionFsmEffect>[
        SessionFsmEffect.startVideoRecording,
        SessionFsmEffect.speakCue,
      ],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickRecording(ClinicalSessionFsmState current) {
    final nextElapsed = current.elapsedSec + 1;
    final totalDuration = current.protocol.durationSec;

    if (nextElapsed >= totalDuration) {
      return (
        state: current.copyWith(
          stage: SessionStage.reviewRecorded,
          elapsedSec: totalDuration,
          recordedDurationSec: totalDuration,
          activeCue: current.protocol.cueForElapsed(totalDuration),
        ),
        effects: const <SessionFsmEffect>[
          SessionFsmEffect.stopVideoRecording,
          SessionFsmEffect.stopVoice,
          SessionFsmEffect.playCompletionChime,
        ],
      );
    }

    final milestone = current.protocol.milestoneAt(nextElapsed);
    final effects = milestone != null
        ? const <SessionFsmEffect>[SessionFsmEffect.speakCue]
        : const <SessionFsmEffect>[];

    return (
      state: current.copyWith(
        elapsedSec: nextElapsed,
        activeCue: milestone ?? current.activeCue,
      ),
      effects: effects,
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      requestStopRecording(ClinicalSessionFsmState current) {
    if (current.stage == SessionStage.countdown) {
      return (
        state: current.copyWith(
          stage: SessionStage.readyToRecord,
          countdownRemainingSec: countdownDurationSec,
          elapsedSec: 0,
          recordedDurationSec: 0,
          clearVideoPath: true,
        ),
        effects: const <SessionFsmEffect>[SessionFsmEffect.stopVoice],
      );
    }
    if (current.stage != SessionStage.recordingActive) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.reviewRecorded,
        recordedDurationSec: current.elapsedSec,
      ),
      effects: const <SessionFsmEffect>[
        SessionFsmEffect.stopVideoRecording,
        SessionFsmEffect.stopVoice,
        SessionFsmEffect.playCompletionChime,
      ],
    );
  }

  ClinicalSessionFsmState attachRecordedVideoPath(
    ClinicalSessionFsmState current,
    String videoPath,
  ) {
    return current.copyWith(recordedVideoPath: videoPath);
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      requestRetake(ClinicalSessionFsmState current) {
    if (current.stage != SessionStage.reviewRecorded &&
        current.stage != SessionStage.analyzingVideo) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.readyToRecord,
        countdownRemainingSec: countdownDurationSec,
        elapsedSec: 0,
        recordedDurationSec: 0,
        clearVideoPath: true,
        clearAnalysisProgress: true,
        analysisProcessedFrames: 0,
        analysisTotalFrames: 0,
        analysisStageLabel: '',
        activeCue: current.protocol.cueForElapsed(0),
      ),
      effects: const <SessionFsmEffect>[
        SessionFsmEffect.stopVoice,
        SessionFsmEffect.deleteTempVideo,
      ],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      requestSubmitVideo(ClinicalSessionFsmState current) {
    if (current.stage != SessionStage.reviewRecorded ||
        !current.canSubmitVideo) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.analyzingVideo,
        clearAnalysisProgress: true,
        analysisProcessedFrames: 0,
        analysisTotalFrames: 0,
        analysisStageLabel: 'Menyiapkan Pose Extractor...',
      ),
      effects: const <SessionFsmEffect>[SessionFsmEffect.beginVideoAnalysis],
    );
  }

  ClinicalSessionFsmState toggleSound(ClinicalSessionFsmState current) {
    return current.copyWith(soundEnabled: !current.soundEnabled);
  }

  /// Removes isolated single-window positive spikes shorter than [minRun]
  /// (`postprocess_fog_windows(min_run=2)` parity).
  static List<WindowPredictionItem> applyMinRunPostProcessing(
    List<WindowPredictionItem> rawWindows, {
    int minRun = minRunWindows,
  }) {
    if (rawWindows.isEmpty) return const <WindowPredictionItem>[];
    final postFlags = List<bool>.filled(rawWindows.length, false);
    var runStart = -1;
    for (var i = 0; i < rawWindows.length; i++) {
      if (rawWindows[i].predRaw) {
        if (runStart == -1) runStart = i;
      } else if (runStart != -1) {
        if (i - runStart >= minRun) {
          for (var j = runStart; j < i; j++) {
            postFlags[j] = true;
          }
        }
        runStart = -1;
      }
    }
    if (runStart != -1 && rawWindows.length - runStart >= minRun) {
      for (var j = runStart; j < rawWindows.length; j++) {
        postFlags[j] = true;
      }
    }

    return List<WindowPredictionItem>.unmodifiable(
      List<WindowPredictionItem>.generate(rawWindows.length, (i) {
        final w = rawWindows[i];
        return WindowPredictionItem(
          windowIdx: w.windowIdx,
          startSec: w.startSec,
          endSec: w.endSec,
          rawProb: w.rawProb,
          calibratedScore: w.calibratedScore,
          predRaw: w.predRaw,
          predPostprocessed: postFlags[i],
          freezeIndexAnkle: w.freezeIndexAnkle,
          bilateralAsymAnkle: w.bilateralAsymAnkle,
          lowQualityFlag: w.lowQualityFlag,
        );
      }),
    );
  }

  /// Groups contiguous confirmed (`predPostprocessed`) windows into episodes.
  static List<FogEpisodeItem> extractConfirmedEpisodes(
    List<WindowPredictionItem> windows,
  ) {
    final episodes = <FogEpisodeItem>[];
    var inRun = false;
    var startSec = 0.0;
    var endSec = 0.0;
    var peakScore = 0.0;
    var freezeSum = 0.0;
    var count = 0;

    for (final w in windows) {
      if (w.predPostprocessed) {
        if (!inRun) {
          inRun = true;
          startSec = w.startSec;
          endSec = w.endSec;
          peakScore = w.calibratedScore;
          freezeSum = w.freezeIndexAnkle;
          count = 1;
        } else {
          endSec = math.max(endSec, w.endSec);
          peakScore = math.max(peakScore, w.calibratedScore);
          freezeSum += w.freezeIndexAnkle;
          count++;
        }
      } else if (inRun) {
        episodes.add(
          FogEpisodeItem(
            episodeIndex: episodes.length + 1,
            startSec: startSec,
            endSec: endSec,
            peakCalibratedScore: peakScore,
            meanFreezeIndex: count == 0 ? 0.0 : freezeSum / count,
          ),
        );
        inRun = false;
      }
    }
    if (inRun) {
      episodes.add(
        FogEpisodeItem(
          episodeIndex: episodes.length + 1,
          startSec: startSec,
          endSec: endSec,
          peakCalibratedScore: peakScore,
          meanFreezeIndex: count == 0 ? 0.0 : freezeSum / count,
        ),
      );
    }
    return List<FogEpisodeItem>.unmodifiable(episodes);
  }
}
