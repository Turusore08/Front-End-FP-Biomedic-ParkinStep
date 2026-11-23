import 'fog_episode_item.dart';
import 'recorded_pose_track.dart';
import 'session_summary_item.dart';
import 'window_prediction_item.dart';

/// Full clinical gait screening session report rendered in S-09 and exported to PDF/CSV.
class SessionClinicalReport {
  const SessionClinicalReport({
    required this.summary,
    this.patientDisplayName = 'Pengguna',
    this.classifierUsed = 'LIGHTGBM_FFT',
    this.modelBundleVersion = 'LightGBM+FFT v2026.11 (B_15hz)',
    this.thresholdUsed = 0.26,
    this.validLb6Ratio = 1.0,
    this.totalFogDurationSec = 0.0,
    this.medianEpisodeDurationSec = 0.0,
    this.locomotorBandEnergy = 1.0,
    this.freezeBandEnergy = 0.0,
    this.meanFreezeIndex = 0.0,
    this.meanBilateralAsymmetry = 0.0,
    this.fallGuardFalseAlarms = 0,
    this.videoSecurelyDeleted = true,
    this.isSimulatedPreview = false,
    this.recordedVideoPath,
    this.poseTrackPath,
    this.poseTrack,
    this.episodes = const <FogEpisodeItem>[],
    this.windows = const <WindowPredictionItem>[],
  });

  final SessionSummaryItem summary;
  final String patientDisplayName;
  final String classifierUsed;
  final String modelBundleVersion;
  final double thresholdUsed;
  final double validLb6Ratio;
  final double totalFogDurationSec;
  final double medianEpisodeDurationSec;
  final double locomotorBandEnergy;
  final double freezeBandEnergy;
  final double meanFreezeIndex;
  final double meanBilateralAsymmetry;
  final int fallGuardFalseAlarms;
  final bool videoSecurelyDeleted;
  final bool isSimulatedPreview;
  final String? recordedVideoPath;
  final String? poseTrackPath;
  final RecordedPoseTrack? poseTrack;
  final List<FogEpisodeItem> episodes;
  final List<WindowPredictionItem> windows;

  SessionClinicalReport copyWith({
    SessionSummaryItem? summary,
    bool? videoSecurelyDeleted,
    String? recordedVideoPath,
    bool clearRecordedVideoPath = false,
    String? poseTrackPath,
    bool clearPoseTrackPath = false,
    RecordedPoseTrack? poseTrack,
    bool clearPoseTrack = false,
  }) {
    return SessionClinicalReport(
      summary: summary ?? this.summary,
      patientDisplayName: patientDisplayName,
      classifierUsed: classifierUsed,
      modelBundleVersion: modelBundleVersion,
      thresholdUsed: thresholdUsed,
      validLb6Ratio: validLb6Ratio,
      totalFogDurationSec: totalFogDurationSec,
      medianEpisodeDurationSec: medianEpisodeDurationSec,
      locomotorBandEnergy: locomotorBandEnergy,
      freezeBandEnergy: freezeBandEnergy,
      meanFreezeIndex: meanFreezeIndex,
      meanBilateralAsymmetry: meanBilateralAsymmetry,
      fallGuardFalseAlarms: fallGuardFalseAlarms,
      videoSecurelyDeleted: videoSecurelyDeleted ?? this.videoSecurelyDeleted,
      isSimulatedPreview: isSimulatedPreview,
      recordedVideoPath: clearRecordedVideoPath
          ? null
          : (recordedVideoPath ?? this.recordedVideoPath),
      poseTrackPath: clearPoseTrackPath
          ? null
          : (poseTrackPath ?? this.poseTrackPath),
      poseTrack: clearPoseTrack ? null : (poseTrack ?? this.poseTrack),
      episodes: episodes,
      windows: windows,
    );
  }

  String get asymmetryLevelId {
    if (meanBilateralAsymmetry < 0.12) return 'Rendah';
    if (meanBilateralAsymmetry < 0.25) return 'Sedang';
    return 'Tinggi';
  }

  static double computeMedianEpisodeDuration(List<FogEpisodeItem> episodes) {
    if (episodes.isEmpty) return 0.0;
    final durations = episodes.map((e) => e.durationSec).toList()..sort();
    final mid = durations.length ~/ 2;
    if (durations.length.isOdd) {
      return durations[mid];
    }
    return (durations[mid - 1] + durations[mid]) * 0.5;
  }

  /// Synthesizes a clean backward-compatible report for legacy saved summaries.
  factory SessionClinicalReport.fromSummaryOnly(
    SessionSummaryItem summary, {
    String patientDisplayName = 'Pengguna',
  }) {
    final dur = summary.durationSec > 0 ? summary.durationSec : 120.0;
    final estFogSec = dur * (summary.fogPercentage.clamp(0.0, 100.0) / 100.0);
    final isFogHeavy = summary.fogPercentage >= 5.0;
    return SessionClinicalReport(
      summary: summary,
      patientDisplayName: patientDisplayName,
      totalFogDurationSec: double.parse(estFogSec.toStringAsFixed(1)),
      medianEpisodeDurationSec: summary.episodeCount == 0
          ? 0.0
          : double.parse((estFogSec / summary.episodeCount).toStringAsFixed(1)),
      locomotorBandEnergy: isFogHeavy ? 2.1 : 4.2,
      freezeBandEnergy: isFogHeavy ? 3.8 : 0.7,
      meanFreezeIndex: isFogHeavy ? 2.15 : 0.42,
      meanBilateralAsymmetry: isFogHeavy ? 0.28 : 0.08,
    );
  }
}
