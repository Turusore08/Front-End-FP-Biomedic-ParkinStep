import '../value_objects/calibrated_risk_score.dart';
import '../value_objects/keypoint_2d.dart';

/// Immutable 15 Hz Edge-AI inference output consumed by FSM and 60 FPS Skeleton HUD.
class LiveFrameResult {
  const LiveFrameResult({
    required this.sequenceId,
    required this.timestampMs,
    required this.imageWidth,
    required this.imageHeight,
    required this.keypoints17,
    required this.lb6AvgConf,
    required this.effectiveFps,
    required this.rawProb,
    this.thresholdUsed = CalibratedRiskScore.defaultLightGbmThreshold,
    this.freezeIndex = 0.0,
    this.isLowQualityWindow = false,
    this.hipDropRatio = 0.0,
    this.isImmobile = false,
  });

  final int sequenceId;
  final int timestampMs;
  final double imageWidth;
  final double imageHeight;
  final List<Keypoint2D> keypoints17;
  final double lb6AvgConf;
  final double effectiveFps;
  final double rawProb;
  final double thresholdUsed;
  final double freezeIndex;
  final bool isLowQualityWindow;
  final double hipDropRatio;
  final bool isImmobile;

  double get calibratedRiskScore => CalibratedRiskScore.fromRawProbability(
        rawProb,
        threshold: thresholdUsed,
      );
}
