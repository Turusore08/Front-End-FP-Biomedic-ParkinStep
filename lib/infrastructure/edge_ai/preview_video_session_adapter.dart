import 'dart:async';
import 'dart:math' as math;

import '../../application/ports/video_session_port.dart';
import '../../application/state_machines/clinical_session_fsm.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/video_analysis_result.dart';
import '../../domain/entities/window_prediction_item.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/enums/session_protocol.dart';
import '../../domain/value_objects/calibrated_risk_score.dart';

/// Deterministic synthetic [VideoSessionPort] for Flutter widget tests and
/// preview builds without physical camera/ONNX execution.
class PreviewVideoSessionAdapter implements VideoSessionPort {
  PreviewGaitScenario _scenario = PreviewGaitScenario.normalGait;
  bool _cancelRequested = false;
  int _recordingSeq = 0;

  @override
  bool get isPreviewSimulation => true;

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> openCameraPreview() async {}

  @override
  Future<void> startRecording() async {}

  @override
  Future<String> stopRecording() async {
    _recordingSeq++;
    return 'preview://recorded_session_$_recordingSeq.mp4';
  }

  @override
  Future<void> closeCameraPreview() async {}

  @override
  void cancelAnalysis() {
    _cancelRequested = true;
  }

  @override
  Future<void> secureDeleteVideo(String? videoPath) async {}

  @override
  void setPreviewScenario(PreviewGaitScenario scenario) {
    _scenario = scenario;
  }

  @override
  Future<VideoAnalysisResult> analyzeRecordedVideo({
    required String videoPath,
    required SessionProtocol protocol,
    required double fallbackDurationSec,
    required void Function(VideoAnalysisProgress progress) onProgress,
  }) async {
    _cancelRequested = false;
    final durSec = math.max(4.0, fallbackDurationSec);
    final totalFrames = math.max(30, (durSec * 15).round());

    onProgress(
      VideoAnalysisProgress(
        processedFrames: (totalFrames * 0.25).round(),
        totalFrames: totalFrames,
        stageLabelId: 'Mengekstrak sendi dari video...',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (_cancelRequested) {
      throw StateError('Analisis dibatalkan.');
    }

    onProgress(
      VideoAnalysisProgress(
        processedFrames: (totalFrames * 0.70).round(),
        totalFrames: totalFrames,
        stageLabelId: 'Menghitung fitur FFT & Freeze Index...',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (_cancelRequested) {
      throw StateError('Analisis dibatalkan.');
    }

    final windowCount = math.max(3, (durSec - 1).round());
    final rawWindows = List<WindowPredictionItem>.generate(windowCount, (i) {
      final isFogScenario = _scenario == PreviewGaitScenario.confirmedFog ||
          _scenario == PreviewGaitScenario.suddenFall;
      final isFogWindow = isFogScenario &&
          (i >= 1 && i <= math.max(2, (windowCount * 0.4).round()));
      final isLowQuality = _scenario == PreviewGaitScenario.lowLightOcclusion;
      final rawProb = isFogWindow ? 0.64 : (isLowQuality ? 0.09 : 0.08);
      final calScore = CalibratedRiskScore.fromRawProbability(
        rawProb,
        threshold: CalibratedRiskScore.defaultLightGbmThreshold,
      );
      return WindowPredictionItem(
        windowIdx: i,
        startSec: i.toDouble(),
        endSec: i + 2.0,
        rawProb: rawProb,
        calibratedScore: calScore,
        predRaw: rawProb >= CalibratedRiskScore.defaultLightGbmThreshold,
        predPostprocessed: false,
        freezeIndexAnkle: isFogWindow ? 2.41 : 0.42,
        bilateralAsymAnkle: isFogWindow ? 0.26 : 0.07,
        lowQualityFlag: isLowQuality,
      );
    });

    final postWindows = ClinicalSessionFsm.applyMinRunPostProcessing(
      rawWindows,
      minRun: ClinicalSessionFsm.minRunWindows,
    );
    final episodes = ClinicalSessionFsm.extractConfirmedEpisodes(postWindows);
    final confirmedCount =
        postWindows.where((w) => w.predPostprocessed).length;
    final fogPct = ((confirmedCount / postWindows.length) * 100.0).clamp(
      0.0,
      100.0,
    );
    final peakScore = postWindows
        .map((w) => w.calibratedScore)
        .reduce((a, b) => a > b ? a : b);
    final meanFi = postWindows
            .map((w) => w.freezeIndexAnkle)
            .reduce((a, b) => a + b) /
        postWindows.length;
    final meanAsym = postWindows
            .map((w) => w.bilateralAsymAnkle)
            .reduce((a, b) => a + b) /
        postWindows.length;

    onProgress(
      VideoAnalysisProgress(
        processedFrames: totalFrames,
        totalFrames: totalFrames,
        stageLabelId: 'Menghapus video sementara secara otomatis...',
      ),
    );

    return VideoAnalysisResult(
      durationSec: durSec,
      totalFramesProcessed: totalFrames,
      validLb6Ratio:
          _scenario == PreviewGaitScenario.lowLightOcclusion ? 0.45 : 0.96,
      fogPercentage: double.parse(fogPct.toStringAsFixed(1)),
      episodeCount: episodes.length,
      totalFogDurationSec: confirmedCount.toDouble(),
      medianEpisodeDurationSec:
          SessionClinicalReport.computeMedianEpisodeDuration(episodes),
      peakRiskScore: peakScore,
      locomotorBandEnergy: episodes.isNotEmpty ? 2.4 : 4.6,
      freezeBandEnergy: episodes.isNotEmpty ? 3.9 : 0.6,
      meanFreezeIndex: double.parse(meanFi.toStringAsFixed(2)),
      meanBilateralAsymmetry: double.parse(meanAsym.toStringAsFixed(3)),
      thresholdUsed: CalibratedRiskScore.defaultLightGbmThreshold,
      videoSecurelyDeleted: true,
      episodes: episodes,
      windows: postWindows,
    );
  }
}
