import 'fog_episode_item.dart';
import 'recorded_pose_track.dart';
import 'window_prediction_item.dart';

/// Incremental progress update emitted while decoding video and extracting poses.
class VideoAnalysisProgress {
  const VideoAnalysisProgress({
    required this.processedFrames,
    required this.totalFrames,
    required this.stageLabelId,
  });

  final int processedFrames;
  final int totalFrames;
  final String stageLabelId;

  double? get fraction {
    if (totalFrames <= 0) return null;
    return (processedFrames / totalFrames).clamp(0.0, 1.0);
  }
}

/// Complete post-recording pose extraction & Scenario B FoG screening result.
class VideoAnalysisResult {
  const VideoAnalysisResult({
    required this.durationSec,
    required this.totalFramesProcessed,
    required this.validLb6Ratio,
    required this.fogPercentage,
    required this.episodeCount,
    required this.totalFogDurationSec,
    required this.medianEpisodeDurationSec,
    required this.peakRiskScore,
    required this.locomotorBandEnergy,
    required this.freezeBandEnergy,
    required this.meanFreezeIndex,
    required this.meanBilateralAsymmetry,
    required this.thresholdUsed,
    required this.videoSecurelyDeleted,
    required this.episodes,
    required this.windows,
    this.poseTrack,
  });

  final double durationSec;
  final int totalFramesProcessed;
  final double validLb6Ratio;
  final double fogPercentage;
  final int episodeCount;
  final double totalFogDurationSec;
  final double medianEpisodeDurationSec;
  final double peakRiskScore;
  final double locomotorBandEnergy;
  final double freezeBandEnergy;
  final double meanFreezeIndex;
  final double meanBilateralAsymmetry;
  final double thresholdUsed;
  final bool videoSecurelyDeleted;
  final List<FogEpisodeItem> episodes;
  final List<WindowPredictionItem> windows;
  final RecordedPoseTrack? poseTrack;
}
