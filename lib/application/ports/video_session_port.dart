import '../../domain/entities/video_analysis_result.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/enums/session_protocol.dart';

/// Gateway managing video camera capture (no live inference) and post-recording
/// on-device pose extraction + scenario B FoG classification with auto video cleanup.
abstract interface class VideoSessionPort {
  bool get isPreviewSimulation;

  /// Preloads ONNX pose & FoG models in the background so post-recording
  /// analysis starts rapidly without stalling on NNAPI compilation.
  Future<void> warmUp();

  Future<void> openCameraPreview();

  Future<void> startRecording();

  /// Stops camera video recording and returns the local temporary `.mp4` path.
  Future<String> stopRecording();

  Future<void> closeCameraPreview();

  /// Runs sequential 15 Hz frame decoding, `yolo26n-pose.onnx` extraction,
  /// batch exact Scenario B DSP, and `lgbm_b15hz.onnx` scoring over [videoPath],
  /// then securely wipes and deletes the video file.
  Future<VideoAnalysisResult> analyzeRecordedVideo({
    required String videoPath,
    required SessionProtocol protocol,
    required double fallbackDurationSec,
    required void Function(VideoAnalysisProgress progress) onProgress,
  });

  void cancelAnalysis();

  Future<void> secureDeleteVideo(String? videoPath);

  void setPreviewScenario(PreviewGaitScenario scenario);
}
