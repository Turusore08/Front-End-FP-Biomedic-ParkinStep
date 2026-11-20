/// Confirmed Freezing of Gait (FoG) episode interval (`min_run >= 2` windows).
class FogEpisodeItem {
  const FogEpisodeItem({
    required this.episodeIndex,
    required this.startSec,
    required this.endSec,
    required this.peakCalibratedScore,
    required this.meanFreezeIndex,
  });

  final int episodeIndex;
  final double startSec;
  final double endSec;
  final double peakCalibratedScore;
  final double meanFreezeIndex;

  double get durationSec => (endSec - startSec).clamp(0.0, 10000.0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FogEpisodeItem &&
        other.episodeIndex == episodeIndex &&
        other.startSec == startSec &&
        other.endSec == endSec &&
        other.peakCalibratedScore == peakCalibratedScore &&
        other.meanFreezeIndex == meanFreezeIndex;
  }

  @override
  int get hashCode => Object.hash(
        episodeIndex,
        startSec,
        endSec,
        peakCalibratedScore,
        meanFreezeIndex,
      );
}
