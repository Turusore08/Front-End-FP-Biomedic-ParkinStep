import 'dart:math' as math;

import '../../domain/entities/fog_episode_item.dart';
import '../../domain/entities/live_frame_result.dart';
import '../../domain/entities/window_prediction_item.dart';
import '../../domain/enums/alert_tier.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/session_stage.dart';
import '../../domain/value_objects/calibrated_risk_score.dart';
import '../../domain/value_objects/keypoint_2d.dart';

/// Side effects emitted deterministically by ClinicalSessionFsm transitions.
enum SessionFsmEffect {
  playEarlyWarningChime,
  startFogCueing,
  stopFogCueing,
  startFallGuardAlarm,
  stopFallGuardAlarm,
  dispatchEmergencyAlert,
  beginPostSessionAnalysis,
}

/// Immutable state snapshot governed by ClinicalSessionFsm.
class ClinicalSessionFsmState {
  const ClinicalSessionFsmState({
    this.stage = SessionStage.framingCheck,
    this.alertTier = AlertTier.gaitNormal,
    this.medState = MedicationState.unknown,
    this.framingGoodSec = 0,
    this.lowLightBadSec = 0,
    this.showLowLightError = false,
    this.calibrationRemainingSec = ClinicalSessionFsm.calibrationDurationSec,
    this.elapsedSec = 0,
    this.consecutivePositiveWindows = 0,
    this.consecutiveNormalWindows = 0,
    this.prolongedFreezeSec = 0,
    this.hipDropImmobileSec = 0,
    this.totalWindowCount = 0,
    this.confirmedFogWindowCount = 0,
    this.episodeCount = 0,
    this.peakRiskScore = 0.0,
    this.freezeIndexSum = 0.0,
    this.validLb6Sum = 0.0,
    this.validLb6Count = 0,
    this.fallCountdownSec = ClinicalSessionFsm.fallGuardDurationSec,
    this.fallTriggerReason = '',
    this.fallGuardFalseAlarms = 0,
    this.recordedWindows = const <WindowPredictionItem>[],
    this.latestFrame,
  });

  final SessionStage stage;
  final AlertTier alertTier;
  final MedicationState medState;
  final int framingGoodSec;
  final int lowLightBadSec;
  final bool showLowLightError;
  final int calibrationRemainingSec;
  final int elapsedSec;
  final int consecutivePositiveWindows;
  final int consecutiveNormalWindows;
  final int prolongedFreezeSec;
  final int hipDropImmobileSec;
  final int totalWindowCount;
  final int confirmedFogWindowCount;
  final int episodeCount;
  final double peakRiskScore;
  final double freezeIndexSum;
  final double validLb6Sum;
  final int validLb6Count;
  final int fallCountdownSec;
  final String fallTriggerReason;
  final int fallGuardFalseAlarms;
  final List<WindowPredictionItem> recordedWindows;
  final LiveFrameResult? latestFrame;

  double get averageLb6Conf => validLb6Count == 0
      ? (latestFrame?.lb6AvgConf ?? 0.0)
      : (validLb6Sum / validLb6Count);

  ClinicalSessionFsmState copyWith({
    SessionStage? stage,
    AlertTier? alertTier,
    MedicationState? medState,
    int? framingGoodSec,
    int? lowLightBadSec,
    bool? showLowLightError,
    int? calibrationRemainingSec,
    int? elapsedSec,
    int? consecutivePositiveWindows,
    int? consecutiveNormalWindows,
    int? prolongedFreezeSec,
    int? hipDropImmobileSec,
    int? totalWindowCount,
    int? confirmedFogWindowCount,
    int? episodeCount,
    double? peakRiskScore,
    double? freezeIndexSum,
    double? validLb6Sum,
    int? validLb6Count,
    int? fallCountdownSec,
    String? fallTriggerReason,
    int? fallGuardFalseAlarms,
    List<WindowPredictionItem>? recordedWindows,
    LiveFrameResult? latestFrame,
  }) {
    return ClinicalSessionFsmState(
      stage: stage ?? this.stage,
      alertTier: alertTier ?? this.alertTier,
      medState: medState ?? this.medState,
      framingGoodSec: framingGoodSec ?? this.framingGoodSec,
      lowLightBadSec: lowLightBadSec ?? this.lowLightBadSec,
      showLowLightError: showLowLightError ?? this.showLowLightError,
      calibrationRemainingSec:
          calibrationRemainingSec ?? this.calibrationRemainingSec,
      elapsedSec: elapsedSec ?? this.elapsedSec,
      consecutivePositiveWindows:
          consecutivePositiveWindows ?? this.consecutivePositiveWindows,
      consecutiveNormalWindows:
          consecutiveNormalWindows ?? this.consecutiveNormalWindows,
      prolongedFreezeSec: prolongedFreezeSec ?? this.prolongedFreezeSec,
      hipDropImmobileSec: hipDropImmobileSec ?? this.hipDropImmobileSec,
      totalWindowCount: totalWindowCount ?? this.totalWindowCount,
      confirmedFogWindowCount:
          confirmedFogWindowCount ?? this.confirmedFogWindowCount,
      episodeCount: episodeCount ?? this.episodeCount,
      peakRiskScore: peakRiskScore ?? this.peakRiskScore,
      freezeIndexSum: freezeIndexSum ?? this.freezeIndexSum,
      validLb6Sum: validLb6Sum ?? this.validLb6Sum,
      validLb6Count: validLb6Count ?? this.validLb6Count,
      fallCountdownSec: fallCountdownSec ?? this.fallCountdownSec,
      fallTriggerReason: fallTriggerReason ?? this.fallTriggerReason,
      fallGuardFalseAlarms: fallGuardFalseAlarms ?? this.fallGuardFalseAlarms,
      recordedWindows: recordedWindows ?? this.recordedWindows,
      latestFrame: latestFrame ?? this.latestFrame,
    );
  }
}

/// Pure deterministic Finite State Machine implementing S-05 framing/calibration,
/// S-06 Two-Tier FoG Debounce (`min_run=2`, 2-window hysteresis), and S-08 Fall Guard.
class ClinicalSessionFsm {
  const ClinicalSessionFsm();

  static const int sessionDurationSec = 120;
  static const int framingLockRequiredSec = 2;
  static const int calibrationDurationSec = 3;
  static const int lowLightLossLimitSec = 3;
  static const int prolongedFreezeLimitSec = 15;
  static const double hipDropThresholdRatio = 0.65;
  static const int hipDropImmobilitySec = 3;
  static const int fallGuardDurationSec = 10;
  static const int minRunWindows = 2;
  static const int recoveryHysteresisWindows = 2;

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      onLiveFrame(
    ClinicalSessionFsmState current,
    LiveFrameResult frame,
  ) {
    final trackConf = current.stage == SessionStage.framingCheck ||
        current.stage == SessionStage.calibratingStanding ||
        current.stage == SessionStage.recordingActive;

    var nextPeak = current.peakRiskScore;
    if (current.stage == SessionStage.recordingActive &&
        frame.calibratedRiskScore > nextPeak) {
      nextPeak = frame.calibratedRiskScore;
    }

    return (
      state: current.copyWith(
        latestFrame: frame,
        peakRiskScore: nextPeak,
        validLb6Sum:
            trackConf ? current.validLb6Sum + frame.lb6AvgConf : null,
        validLb6Count: trackConf ? current.validLb6Count + 1 : null,
      ),
      effects: const <SessionFsmEffect>[],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      onOneSecondTick(
    ClinicalSessionFsmState current,
  ) {
    switch (current.stage) {
      case SessionStage.framingCheck:
        return _tickFraming(current);
      case SessionStage.calibratingStanding:
        return _tickCalibration(current);
      case SessionStage.recordingActive:
        return _tickRecording(current);
      case SessionStage.fallGuardActive:
        return _tickFallGuard(current);
      case SessionStage.emergencyDispatched:
      case SessionStage.postSessionAnalyzing:
      case SessionStage.summaryReady:
        return (state: current, effects: const <SessionFsmEffect>[]);
    }
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      retryCalibration(
    ClinicalSessionFsmState current,
  ) {
    return (
      state: current.copyWith(
        stage: SessionStage.framingCheck,
        showLowLightError: false,
        lowLightBadSec: 0,
        framingGoodSec: 0,
        calibrationRemainingSec: calibrationDurationSec,
      ),
      effects: const <SessionFsmEffect>[],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      cancelFallGuard(
    ClinicalSessionFsmState current,
  ) {
    if (current.stage != SessionStage.fallGuardActive) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.recordingActive,
        alertTier: AlertTier.gaitNormal,
        consecutivePositiveWindows: 0,
        consecutiveNormalWindows: 0,
        prolongedFreezeSec: 0,
        hipDropImmobileSec: 0,
        fallCountdownSec: fallGuardDurationSec,
        fallTriggerReason: '',
        fallGuardFalseAlarms: current.fallGuardFalseAlarms + 1,
      ),
      effects: const <SessionFsmEffect>[SessionFsmEffect.stopFallGuardAlarm],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      triggerEmergencyNow(
    ClinicalSessionFsmState current,
  ) {
    if (current.stage != SessionStage.fallGuardActive) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    return (
      state: current.copyWith(
        stage: SessionStage.emergencyDispatched,
        fallCountdownSec: 0,
      ),
      effects: const <SessionFsmEffect>[SessionFsmEffect.dispatchEmergencyAlert],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      requestManualFinish(
    ClinicalSessionFsmState current,
  ) {
    if (current.stage == SessionStage.postSessionAnalyzing ||
        current.stage == SessionStage.summaryReady) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }

    final effects = <SessionFsmEffect>[];
    if (current.alertTier == AlertTier.fogConfirmed) {
      effects.add(SessionFsmEffect.stopFogCueing);
    }
    if (current.stage == SessionStage.fallGuardActive ||
        current.stage == SessionStage.emergencyDispatched) {
      effects.add(SessionFsmEffect.stopFallGuardAlarm);
    }
    effects.add(SessionFsmEffect.beginPostSessionAnalysis);

    return (
      state: current.copyWith(stage: SessionStage.postSessionAnalyzing),
      effects: List<SessionFsmEffect>.unmodifiable(effects),
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickFraming(
    ClinicalSessionFsmState current,
  ) {
    if (current.showLowLightError) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }
    final frame = current.latestFrame;
    if (frame == null) {
      return (state: current, effects: const <SessionFsmEffect>[]);
    }

    if (frame.lb6AvgConf >= Keypoint2D.confValidThreshold) {
      final nextGood = current.framingGoodSec + 1;
      if (nextGood >= framingLockRequiredSec) {
        return (
          state: current.copyWith(
            stage: SessionStage.calibratingStanding,
            framingGoodSec: nextGood,
            lowLightBadSec: 0,
            calibrationRemainingSec: calibrationDurationSec,
          ),
          effects: const <SessionFsmEffect>[],
        );
      }
      return (
        state: current.copyWith(framingGoodSec: nextGood, lowLightBadSec: 0),
        effects: const <SessionFsmEffect>[],
      );
    }

    final nextBad = current.lowLightBadSec + 1;
    if (nextBad > lowLightLossLimitSec) {
      return (
        state: current.copyWith(
          framingGoodSec: 0,
          lowLightBadSec: nextBad,
          showLowLightError: true,
        ),
        effects: const <SessionFsmEffect>[],
      );
    }
    return (
      state: current.copyWith(framingGoodSec: 0, lowLightBadSec: nextBad),
      effects: const <SessionFsmEffect>[],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickCalibration(
    ClinicalSessionFsmState current,
  ) {
    final frame = current.latestFrame;
    if (frame != null && frame.lb6AvgConf < Keypoint2D.confValidThreshold) {
      final nextBad = current.lowLightBadSec + 1;
      if (nextBad > lowLightLossLimitSec) {
        return (
          state: current.copyWith(
            stage: SessionStage.framingCheck,
            framingGoodSec: 0,
            lowLightBadSec: nextBad,
            showLowLightError: true,
            calibrationRemainingSec: calibrationDurationSec,
          ),
          effects: const <SessionFsmEffect>[],
        );
      }
      return (
        state: current.copyWith(lowLightBadSec: nextBad),
        effects: const <SessionFsmEffect>[],
      );
    }

    final nextRem = current.calibrationRemainingSec - 1;
    if (nextRem <= 0) {
      return (
        state: current.copyWith(
          stage: SessionStage.recordingActive,
          alertTier: AlertTier.gaitNormal,
          lowLightBadSec: 0,
          calibrationRemainingSec: 0,
        ),
        effects: const <SessionFsmEffect>[],
      );
    }
    return (
      state: current.copyWith(
        lowLightBadSec: 0,
        calibrationRemainingSec: nextRem,
      ),
      effects: const <SessionFsmEffect>[],
    );
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickRecording(
    ClinicalSessionFsmState current,
  ) {
    final frame = current.latestFrame;
    final nextElapsed = current.elapsedSec + 1;
    final p = frame?.rawProb ?? 0.0;
    final thr =
        frame?.thresholdUsed ?? CalibratedRiskScore.defaultLightGbmThreshold;
    final isPositive = p >= thr;

    final nextTotalWin = current.totalWindowCount + 1;
    final nextFreezeSum = current.freezeIndexSum + (frame?.freezeIndex ?? 0.0);
    final windowIdx = current.recordedWindows.length;
    final startSec = windowIdx.toDouble();
    final endSec = startSec + 2.0;
    final calibratedScore = frame?.calibratedRiskScore ?? 0.0;
    final asym = _computeAnkleAsymmetry(frame);

    // 1. Sudden Hip Drop + Immobility check (>= 0.65 * leg_length & immobile >= 3s)
    final isHipDropped = frame != null &&
        frame.hipDropRatio >= hipDropThresholdRatio &&
        frame.isImmobile;
    final nextHipDropSec = isHipDropped ? current.hipDropImmobileSec + 1 : 0;

    if (nextHipDropSec >= hipDropImmobilitySec) {
      final updatedWindows = <WindowPredictionItem>[
        ...current.recordedWindows,
        WindowPredictionItem(
          windowIdx: windowIdx,
          startSec: startSec,
          endSec: endSec,
          rawProb: p,
          calibratedScore: calibratedScore,
          predRaw: isPositive,
          predPostprocessed: isPositive && current.consecutivePositiveWindows >= 1,
          freezeIndexAnkle: frame?.freezeIndex ?? 0.0,
          bilateralAsymAnkle: asym,
          lowQualityFlag: frame?.isLowQualityWindow ?? false,
        ),
      ];
      final effects = <SessionFsmEffect>[
        if (current.alertTier == AlertTier.fogConfirmed)
          SessionFsmEffect.stopFogCueing,
        SessionFsmEffect.startFallGuardAlarm,
      ];
      return (
        state: current.copyWith(
          stage: SessionStage.fallGuardActive,
          alertTier: AlertTier.fallGuard,
          elapsedSec: nextElapsed,
          totalWindowCount: nextTotalWin,
          freezeIndexSum: nextFreezeSum,
          hipDropImmobileSec: nextHipDropSec,
          fallCountdownSec: fallGuardDurationSec,
          recordedWindows: List<WindowPredictionItem>.unmodifiable(updatedWindows),
          fallTriggerReason:
              'Terdeteksi penurunan pinggul mendadak dan kaki tidak bergerak.',
        ),
        effects: List<SessionFsmEffect>.unmodifiable(effects),
      );
    }

    // 2. Two-Tier Alert Debounce (min_run = 2) + 2-window Hysteresis + > 15s Freeze Guard
    var nextTier = current.alertTier;
    var nextPosRuns = current.consecutivePositiveWindows;
    var nextNormRuns = current.consecutiveNormalWindows;
    var nextProlongedFreeze = current.prolongedFreezeSec;
    var nextConfirmedWins = current.confirmedFogWindowCount;
    var nextEpisodes = current.episodeCount;
    final effects = <SessionFsmEffect>[];
    final updatedWindows = List<WindowPredictionItem>.of(current.recordedWindows);
    var currentPredPost = false;

    if (isPositive) {
      nextPosRuns++;
      nextNormRuns = 0;

      if (nextTier == AlertTier.gaitNormal) {
        nextTier = AlertTier.earlyWarning;
        effects.add(SessionFsmEffect.playEarlyWarningChime);
      } else if (nextTier == AlertTier.earlyWarning &&
          nextPosRuns >= minRunWindows) {
        nextTier = AlertTier.fogConfirmed;
        nextEpisodes++;
        nextConfirmedWins += 2;
        nextProlongedFreeze = 2;
        currentPredPost = true;
        if (updatedWindows.isNotEmpty) {
          final prev = updatedWindows.last;
          updatedWindows[updatedWindows.length - 1] = WindowPredictionItem(
            windowIdx: prev.windowIdx,
            startSec: prev.startSec,
            endSec: prev.endSec,
            rawProb: prev.rawProb,
            calibratedScore: prev.calibratedScore,
            predRaw: prev.predRaw,
            predPostprocessed: true,
            freezeIndexAnkle: prev.freezeIndexAnkle,
            bilateralAsymAnkle: prev.bilateralAsymAnkle,
            lowQualityFlag: prev.lowQualityFlag,
          );
        }
        effects.add(SessionFsmEffect.startFogCueing);
      } else if (nextTier == AlertTier.fogConfirmed) {
        nextConfirmedWins++;
        nextProlongedFreeze++;
        currentPredPost = true;
      }
    } else {
      if (nextTier == AlertTier.fogConfirmed) {
        nextNormRuns++;
        if (nextNormRuns >= recoveryHysteresisWindows) {
          nextTier = AlertTier.gaitNormal;
          nextPosRuns = 0;
          nextNormRuns = 0;
          nextProlongedFreeze = 0;
          effects.add(SessionFsmEffect.stopFogCueing);
        }
      } else {
        nextTier = AlertTier.gaitNormal;
        nextPosRuns = 0;
        nextNormRuns = 0;
        nextProlongedFreeze = 0;
      }
    }

    updatedWindows.add(
      WindowPredictionItem(
        windowIdx: windowIdx,
        startSec: startSec,
        endSec: endSec,
        rawProb: p,
        calibratedScore: calibratedScore,
        predRaw: isPositive,
        predPostprocessed: currentPredPost,
        freezeIndexAnkle: frame?.freezeIndex ?? 0.0,
        bilateralAsymAnkle: asym,
        lowQualityFlag: frame?.isLowQualityWindow ?? false,
      ),
    );
    final immutableWindows =
        List<WindowPredictionItem>.unmodifiable(updatedWindows);

    if (isPositive &&
        nextTier == AlertTier.fogConfirmed &&
        nextProlongedFreeze > prolongedFreezeLimitSec) {
      effects.add(SessionFsmEffect.stopFogCueing);
      effects.add(SessionFsmEffect.startFallGuardAlarm);
      return (
        state: current.copyWith(
          stage: SessionStage.fallGuardActive,
          alertTier: AlertTier.fallGuard,
          elapsedSec: nextElapsed,
          totalWindowCount: nextTotalWin,
          freezeIndexSum: nextFreezeSum,
          confirmedFogWindowCount: nextConfirmedWins,
          episodeCount: nextEpisodes,
          prolongedFreezeSec: nextProlongedFreeze,
          hipDropImmobileSec: nextHipDropSec,
          fallCountdownSec: fallGuardDurationSec,
          recordedWindows: immutableWindows,
          fallTriggerReason:
              'Episode kaki membeku bertahan melebihi 15 detik.',
        ),
        effects: List<SessionFsmEffect>.unmodifiable(effects),
      );
    }

    // 3. Complete 120s screening cleanly
    if (nextElapsed >= sessionDurationSec) {
      if (nextTier == AlertTier.fogConfirmed) {
        effects.add(SessionFsmEffect.stopFogCueing);
      }
      effects.add(SessionFsmEffect.beginPostSessionAnalysis);
      return (
        state: current.copyWith(
          stage: SessionStage.postSessionAnalyzing,
          alertTier: nextTier,
          elapsedSec: sessionDurationSec,
          totalWindowCount: nextTotalWin,
          freezeIndexSum: nextFreezeSum,
          confirmedFogWindowCount: nextConfirmedWins,
          episodeCount: nextEpisodes,
          consecutivePositiveWindows: nextPosRuns,
          consecutiveNormalWindows: nextNormRuns,
          prolongedFreezeSec: nextProlongedFreeze,
          hipDropImmobileSec: nextHipDropSec,
          recordedWindows: immutableWindows,
        ),
        effects: List<SessionFsmEffect>.unmodifiable(effects),
      );
    }

    return (
      state: current.copyWith(
        alertTier: nextTier,
        elapsedSec: nextElapsed,
        totalWindowCount: nextTotalWin,
        freezeIndexSum: nextFreezeSum,
        confirmedFogWindowCount: nextConfirmedWins,
        episodeCount: nextEpisodes,
        consecutivePositiveWindows: nextPosRuns,
        consecutiveNormalWindows: nextNormRuns,
        prolongedFreezeSec: nextProlongedFreeze,
        hipDropImmobileSec: nextHipDropSec,
        recordedWindows: immutableWindows,
      ),
      effects: List<SessionFsmEffect>.unmodifiable(effects),
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

  static double _computeAnkleAsymmetry(LiveFrameResult? frame) {
    if (frame == null || frame.keypoints17.length < 17) return 0.0;
    final l = frame.keypoints17[15];
    final r = frame.keypoints17[16];
    if (!l.isValid || !r.isValid) return 0.0;
    final w = frame.imageWidth > 0 ? frame.imageWidth : 480.0;
    final h = frame.imageHeight > 0 ? frame.imageHeight : 640.0;
    final raw = ((l.x - r.x).abs() / w) * 0.5 + ((l.y - r.y).abs() / h);
    return raw.isFinite ? raw.clamp(0.0, 1.0) : 0.0;
  }

  ({ClinicalSessionFsmState state, List<SessionFsmEffect> effects})
      _tickFallGuard(
    ClinicalSessionFsmState current,
  ) {
    final nextCountdown = current.fallCountdownSec - 1;
    if (nextCountdown <= 0) {
      return (
        state: current.copyWith(
          stage: SessionStage.emergencyDispatched,
          fallCountdownSec: 0,
        ),
        effects: const <SessionFsmEffect>[
          SessionFsmEffect.dispatchEmergencyAlert,
        ],
      );
    }
    return (
      state: current.copyWith(fallCountdownSec: nextCountdown),
      effects: const <SessionFsmEffect>[],
    );
  }
}
