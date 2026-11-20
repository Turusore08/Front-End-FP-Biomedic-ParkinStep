/// Per-window (2.0 s window, 1.0 s stride) FoG prediction & kinematic trace item.
class WindowPredictionItem {
  const WindowPredictionItem({
    required this.windowIdx,
    required this.startSec,
    required this.endSec,
    required this.rawProb,
    required this.calibratedScore,
    required this.predRaw,
    required this.predPostprocessed,
    required this.freezeIndexAnkle,
    required this.bilateralAsymAnkle,
    this.lowQualityFlag = false,
  });

  final int windowIdx;
  final double startSec;
  final double endSec;
  final double rawProb;
  final double calibratedScore;
  final bool predRaw;
  final bool predPostprocessed;
  final double freezeIndexAnkle;
  final double bilateralAsymAnkle;
  final bool lowQualityFlag;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WindowPredictionItem &&
        other.windowIdx == windowIdx &&
        other.startSec == startSec &&
        other.endSec == endSec &&
        other.rawProb == rawProb &&
        other.calibratedScore == calibratedScore &&
        other.predRaw == predRaw &&
        other.predPostprocessed == predPostprocessed &&
        other.freezeIndexAnkle == freezeIndexAnkle &&
        other.bilateralAsymAnkle == bilateralAsymAnkle &&
        other.lowQualityFlag == lowQualityFlag;
  }

  @override
  int get hashCode => Object.hash(
        windowIdx,
        startSec,
        endSec,
        rawProb,
        calibratedScore,
        predRaw,
        predPostprocessed,
        freezeIndexAnkle,
        bilateralAsymAnkle,
        lowQualityFlag,
      );
}
