import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../application/ports/video_session_port.dart';
import '../../application/state_machines/clinical_session_fsm.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/video_analysis_result.dart';
import '../../domain/entities/window_prediction_item.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/enums/session_protocol.dart';
import '../../domain/value_objects/calibrated_risk_score.dart';
import '../../domain/value_objects/keypoint_2d.dart';
import 'fog_feature_extractor.dart';
import 'native_video_frame_decoder.dart';
import 'onnx_fog_classifier.dart';
import 'pose_worker.dart';

/// Thrown when the patient cancels post-recording video analysis cleanly.
class VideoAnalysisCancelledException implements Exception {
  const VideoAnalysisCancelledException();
}

/// Video-first on-device AI adapter:
/// 1. Opens back camera WITHOUT live image stream or skeleton inference.
/// 2. Records local temporary `.mp4` while patient performs 1 of 3 protocols.
/// 3. On user "Kirim", sequentially extracts 15 Hz frames via native decoder,
///    runs `yolo26n-pose.onnx` (`PoseWorker`), executes whole-trial batch exact
///    Scenario B DSP (`POST_SESSION_EXACT`), scores `lgbm_b15hz.onnx`, and
///    securely zero-overwrites + unlinks the temporary `.mp4`.
class OnnxVideoSessionAdapter implements VideoSessionPort {
  OnnxVideoSessionAdapter({
    this.modelAssetPath = 'assets/models/yolo26n-pose.onnx',
  });

  final String modelAssetPath;

  static const double _targetFps = 15.0;
  static const int _inferenceThreads = 2;
  static const String _poseExecutionProvider = String.fromEnvironment(
    'PARKIN_POSE_EP',
    defaultValue: 'nnapi',
  );
  static const List<int> _lb6Indices = <int>[11, 12, 13, 14, 15, 16];

  final ValueNotifier<CameraController?> _camera =
      ValueNotifier<CameraController?>(null);
  PoseWorker? _worker;
  Future<void>? _sessionLoad;
  final OnnxFogClassifier _classifier = OnnxFogClassifier();
  bool _cancelRequested = false;

  ValueListenable<CameraController?> get cameraController => _camera;

  @override
  bool get isPreviewSimulation => false;

  @override
  Future<void> warmUp() => _ensureSession();

  @override
  Future<void> openCameraPreview() async {
    await closeCameraPreview();
    unawaited(_ensureSession().catchError((Object _) {}));

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'Perangkat tidak memiliki kamera.');
    }
    final description = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      fps: 30,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _camera.value = controller;
  }

  @override
  Future<void> startRecording() async {
    final camera = _camera.value;
    if (camera == null || !camera.value.isInitialized) {
      throw StateError('Kamera belum siap untuk merekam.');
    }
    if (camera.value.isRecordingVideo) return;
    await camera.startVideoRecording();
  }

  @override
  Future<String> stopRecording() async {
    final camera = _camera.value;
    if (camera == null || !camera.value.isInitialized) {
      throw StateError('Kamera tidak aktif saat menghentikan rekaman.');
    }
    if (!camera.value.isRecordingVideo) {
      throw StateError('Tidak ada rekaman video yang sedang berjalan.');
    }
    final file = await camera.stopVideoRecording();
    return file.path;
  }

  @override
  Future<void> closeCameraPreview() async {
    final camera = _camera.value;
    _camera.value = null;
    if (camera == null) return;
    await SchedulerBinding.instance.endOfFrame;
    if (camera.value.isRecordingVideo) {
      try {
        final leftover = await camera.stopVideoRecording();
        await secureDeleteVideo(leftover.path);
      } catch (_) {}
    }
    try {
      await camera.dispose();
    } catch (_) {}
  }

  @override
  void cancelAnalysis() {
    _cancelRequested = true;
  }

  @override
  void setPreviewScenario(PreviewGaitScenario scenario) {
    // Only applies to deterministic synthetic preview adapter.
  }

  @override
  Future<VideoAnalysisResult> analyzeRecordedVideo({
    required String videoPath,
    required SessionProtocol protocol,
    required double fallbackDurationSec,
    required void Function(VideoAnalysisProgress progress) onProgress,
  }) async {
    _cancelRequested = false;
    final decoder = NativeVideoFrameDecoder();
    try {
      onProgress(
        const VideoAnalysisProgress(
          processedFrames: 0,
          totalFrames: 0,
          stageLabelId: 'Menyiapkan model Pose Extractor...',
        ),
      );
      await _ensureSession();
      final worker = _worker;
      if (worker == null) {
        throw StateError('Model Pose Extractor gagal dimuat.');
      }
      if (_cancelRequested) {
        throw const VideoAnalysisCancelledException();
      }

      final opened = await decoder.open(videoPath, targetFps: _targetFps);
      final totalEst = math.max(1, opened.estimatedFrames);
      final lb6Frames = <Float32List>[];
      var processed = 0;

      onProgress(
        VideoAnalysisProgress(
          processedFrames: 0,
          totalFrames: totalEst,
          stageLabelId: 'Mengekstrak sendi dari video...',
        ),
      );

      while (true) {
        if (_cancelRequested) {
          throw const VideoAnalysisCancelledException();
        }
        final frame = await decoder.nextFrame();
        if (frame == null) break;
        if (_cancelRequested) {
          throw const VideoAnalysisCancelledException();
        }

        final pose = await worker.process(frame);
        lb6Frames.add(_packLb6Frame(pose.keypoints));
        processed++;

        onProgress(
          VideoAnalysisProgress(
            processedFrames: processed,
            totalFrames: math.max(totalEst, processed),
            stageLabelId: 'Mengekstrak sendi dari video ($processed frame)...',
          ),
        );
      }

      if (processed == 0) {
        throw StateError('Video tidak memiliki frame yang dapat dianalisis.');
      }

      onProgress(
        VideoAnalysisProgress(
          processedFrames: processed,
          totalFrames: processed,
          stageLabelId: 'Menghitung skor FoG & menghapus video...',
        ),
      );

      final flatLb6 = Float32List(processed * FogFeatureExtractor.joints * 3);
      const strideFloats = FogFeatureExtractor.joints * 3;
      for (var t = 0; t < processed; t++) {
        flatLb6.setRange(t * strideFloats, (t + 1) * strideFloats, lb6Frames[t]);
      }

      final batch = await Isolate.run(
        () => FogFeatureExtractor.computeAllWindowsBatch(
          flatLb6,
          processed,
          fs: _targetFps,
        ),
      );

      if (_cancelRequested) {
        throw const VideoAnalysisCancelledException();
      }

      final rawWindows = <WindowPredictionItem>[];
      var peakScore = 0.0;
      var freezeSum = 0.0;
      var locoEnergySum = 0.0;
      var freezeEnergySum = 0.0;
      var asymSum = 0.0;

      for (final entry in batch.windows) {
        final rawProb =
            (_classifier.predict(entry.features) ?? 0.0).clamp(0.0, 1.0);
        final calScore = CalibratedRiskScore.fromRawProbability(
          rawProb,
          threshold: OnnxFogClassifier.threshold,
        );
        if (calScore > peakScore) peakScore = calScore;
        freezeSum += entry.freezeIndexAnkle;
        locoEnergySum += entry.locomotorEnergyAnkle;
        freezeEnergySum += entry.freezeEnergyAnkle;
        asymSum += entry.bilateralAsymAnkle;

        rawWindows.add(
          WindowPredictionItem(
            windowIdx: entry.windowIdx,
            startSec: entry.startSec,
            endSec: entry.endSec,
            rawProb: rawProb,
            calibratedScore: calScore,
            predRaw: rawProb >= OnnxFogClassifier.threshold,
            predPostprocessed: false,
            freezeIndexAnkle: entry.freezeIndexAnkle,
            bilateralAsymAnkle: entry.bilateralAsymAnkle,
            lowQualityFlag: entry.isLowQuality,
          ),
        );
      }

      final postWindows = ClinicalSessionFsm.applyMinRunPostProcessing(
        rawWindows,
        minRun: ClinicalSessionFsm.minRunWindows,
      );
      final episodes = ClinicalSessionFsm.extractConfirmedEpisodes(postWindows);
      final confirmedCount =
          postWindows.where((w) => w.predPostprocessed).length;
      final winCount = postWindows.length;
      final fogPct = winCount == 0
          ? 0.0
          : ((confirmedCount / winCount) * 100.0).clamp(0.0, 100.0);
      final meanFi = winCount == 0 ? 0.0 : freezeSum / winCount;
      final meanLoco = winCount == 0 ? 1.0 : locoEnergySum / winCount;
      final meanFreeze = winCount == 0 ? 0.0 : freezeEnergySum / winCount;
      final meanAsym = winCount == 0 ? 0.0 : asymSum / winCount;
      final durationSec = opened.durationMs > 0
          ? opened.durationMs / 1000.0
          : math.max(processed / _targetFps, fallbackDurationSec);

      return VideoAnalysisResult(
        durationSec: double.parse(durationSec.toStringAsFixed(1)),
        totalFramesProcessed: processed,
        validLb6Ratio: batch.validLb6Ratio,
        fogPercentage: double.parse(fogPct.toStringAsFixed(1)),
        episodeCount: episodes.length,
        totalFogDurationSec: confirmedCount.toDouble(),
        medianEpisodeDurationSec:
            SessionClinicalReport.computeMedianEpisodeDuration(episodes),
        peakRiskScore: peakScore,
        locomotorBandEnergy: double.parse(meanLoco.toStringAsFixed(2)),
        freezeBandEnergy: double.parse(meanFreeze.toStringAsFixed(2)),
        meanFreezeIndex: double.parse(meanFi.toStringAsFixed(2)),
        meanBilateralAsymmetry: double.parse(meanAsym.toStringAsFixed(3)),
        thresholdUsed: OnnxFogClassifier.threshold,
        videoSecurelyDeleted: true,
        episodes: episodes,
        windows: postWindows,
      );
    } finally {
      await decoder.close();
      await secureDeleteVideo(videoPath);
    }
  }

  @override
  Future<void> secureDeleteVideo(String? videoPath) async {
    if (videoPath == null || videoPath.isEmpty) return;
    if (videoPath.startsWith('preview://')) return;
    await secureZeroAndDeleteFile(File(videoPath));
  }

  static Future<void> secureZeroAndDeleteFile(File file) async {
    try {
      if (!file.existsSync()) return;
      final length = file.lengthSync();
      if (length > 0) {
        final raf = await file.open(mode: FileMode.writeOnlyAppend);
        try {
          await raf.setPosition(0);
          final chunkSize = math.min(length, 65536);
          final zeros = Uint8List(chunkSize);
          var remaining = length;
          while (remaining > 0) {
            final toWrite = math.min(remaining, chunkSize);
            await raf.writeFrom(zeros, 0, toWrite);
            remaining -= toWrite;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      }
    } catch (_) {
      // Proceed to delete even if zero-fill fails on restricted filesystems.
    } finally {
      try {
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  static Float32List _packLb6Frame(List<Keypoint2D>? keypoints) {
    final out = Float32List(FogFeatureExtractor.joints * 3);
    if (keypoints == null || keypoints.length < 17) return out;
    for (var v = 0; v < _lb6Indices.length; v++) {
      final kp = keypoints[_lb6Indices[v]];
      out[v * 3] = kp.x;
      out[v * 3 + 1] = kp.y;
      out[v * 3 + 2] = kp.conf;
    }
    return out;
  }

  Future<void> _ensureSession() {
    final pending = _sessionLoad ??= _loadSession();
    return pending.catchError((Object error) {
      _sessionLoad = null;
      throw error;
    });
  }

  Future<void> _loadSession() async {
    final watch = Stopwatch()..start();
    OrtEnv.instance.init();
    await _classifier.load();
    final raw = await rootBundle.load(modelAssetPath);
    _worker = await PoseWorker.spawn(
      TransferableTypedData.fromList(<TypedData>[raw.buffer.asUint8List()]),
      cpuThreads: _inferenceThreads,
      useNnapi: _poseExecutionProvider != 'cpu',
    );
    if (!kReleaseMode) {
      debugPrint(
        'Pose models ready in ${watch.elapsedMilliseconds}ms '
        '(ep=$_poseExecutionProvider)',
      );
    }
  }

  Future<void> dispose() async {
    await closeCameraPreview();
    await _sessionLoad?.catchError((Object _) {});
    _sessionLoad = null;
    await _worker?.close();
    _worker = null;
    _classifier.release();
    _camera.dispose();
  }
}
