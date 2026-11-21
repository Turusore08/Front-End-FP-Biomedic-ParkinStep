import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../application/ports/edge_inference_port.dart';
import '../../domain/entities/live_frame_result.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/value_objects/keypoint_2d.dart';
import 'fog_feature_extractor.dart';
import 'onnx_fog_classifier.dart';
import 'yolo_pose_codec.dart';

/// On-device 15 Hz pipeline: back camera YUV stream -> letterbox (isolate)
/// -> `yolo26n-pose.onnx` -> main-person 17-COCO keypoints -> Scenario B DSP
/// + 126 FFT/kinematic features every 1 s -> `lgbm_b15hz.onnx` p(FoG).
///
/// Each emitted frame carries the most recent window's [LiveFrameResult.rawProb],
/// [LiveFrameResult.freezeIndex] and quality flag; they refresh once per stride.
class OnnxPoseInferenceAdapter implements EdgeInferencePort {
  OnnxPoseInferenceAdapter({
    this.modelAssetPath = 'assets/models/yolo26n-pose.onnx',
  });

  final String modelAssetPath;

  static const Duration _minFrameInterval = Duration(milliseconds: 66);

  /// Features assume 15 Hz sampling; below this the window spans too long.
  static const double _minReliableFps = 12.0;
  static const List<int> _lb6Indices = <int>[11, 12, 13, 14, 15, 16];

  final ValueNotifier<CameraController?> _camera =
      ValueNotifier<CameraController?>(null);
  OrtSession? _session;
  final FogFeatureExtractor _fog = FogFeatureExtractor();
  final OnnxFogClassifier _classifier = OnnxFogClassifier();

  /// Bumped on every new session so late isolate results from a previous
  /// session are dropped.
  int _generation = 0;
  bool _dspBusy = false;
  double _latestProb = 0.0;
  double _latestFreezeIndex = 0.0;
  bool _latestWindowLowQuality = true;
  StreamController<LiveFrameResult>? _controller;
  bool _busy = false;
  int _seq = 0;
  int _lastProcessedMs = 0;
  double _fpsEma = 0;

  /// Initialized back camera while a live stream runs, `null` otherwise.
  /// The UI listens to this to render a `CameraPreview` under the skeleton HUD.
  ValueListenable<CameraController?> get cameraController => _camera;

  @override
  bool get isPreviewSimulation => false;

  @override
  Stream<LiveFrameResult> startLiveStream({required MedicationState medState}) {
    unawaited(_stopCameraAndClose());
    _seq = 0;
    _fpsEma = 0;
    _lastProcessedMs = 0;
    _fog.reset();
    _generation++;
    _dspBusy = false;
    _latestProb = 0.0;
    _latestFreezeIndex = 0.0;
    _latestWindowLowQuality = true;
    final controller = StreamController<LiveFrameResult>.broadcast();
    _controller = controller;
    unawaited(_start(controller));
    return controller.stream;
  }

  @override
  void setPreviewScenario(PreviewGaitScenario scenario) {
    // Synthetic scenarios only apply to the preview adapter.
  }

  @override
  Future<void> stopLiveStream() => _stopCameraAndClose();

  @override
  Future<void> secureDeleteTempVideo() async {
    // Frames are processed in memory only; no temp video file is ever written.
  }

  Future<void> dispose() async {
    await _stopCameraAndClose();
    _session?.release();
    _session = null;
    _classifier.release();
    _camera.dispose();
  }

  Future<void> _start(StreamController<LiveFrameResult> controller) async {
    try {
      await _ensureSession();
      final camera = await _openBackCamera();
      if (controller.isClosed) {
        await camera.dispose();
        return;
      }
      _camera.value = camera;
      await camera.startImageStream(
        (image) => _onImage(image, camera.description, controller),
      );
    } on Object catch (error, stack) {
      if (!controller.isClosed) controller.addError(error, stack);
    }
  }

  Future<void> _ensureSession() async {
    if (_session != null) return;
    OrtEnv.instance.init();
    await _classifier.load();
    final raw = await rootBundle.load(modelAssetPath);
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    _session = OrtSession.fromBuffer(raw.buffer.asUint8List(), options);
    options.release();
  }

  Future<CameraController> _openBackCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'Perangkat tidak memiliki kamera.');
    }
    final description = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final camera = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await camera.initialize();
    return camera;
  }

  void _onImage(
    CameraImage image,
    CameraDescription description,
    StreamController<LiveFrameResult> controller,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || controller.isClosed) return;
    if (now - _lastProcessedMs < _minFrameInterval.inMilliseconds) return;
    if (image.planes.length < 3) return;

    _busy = true;
    final frame = _copyFrame(image, description.sensorOrientation);
    unawaited(_infer(frame, now, controller).whenComplete(() => _busy = false));
  }

  Future<void> _infer(
    YuvFrame frame,
    int startedMs,
    StreamController<LiveFrameResult> controller,
  ) async {
    final session = _session;
    if (session == null) return;
    try {
      final input = await _preprocessInIsolate(frame);
      final output = await _runModel(session, input.tensor);
      if (output == null || controller.isClosed) return;

      final keypoints =
          YoloPoseCodec.decodeMainPerson(output, input.meta) ?? _emptyKeypoints;
      _updateFogWindow(keypoints);
      controller.add(_buildResult(keypoints, input.meta, startedMs));
    } on Object catch (error, stack) {
      if (kDebugMode) debugPrint('ONNX pose inference failed: $error');
      if (!controller.isClosed) controller.addError(error, stack);
    }
  }

  Future<Float32List?> _runModel(OrtSession session, Float32List tensor) async {
    final inputValue = OrtValueTensor.createTensorWithDataList(tensor, <int>[
      1,
      3,
      YoloPoseCodec.inputSize,
      YoloPoseCodec.inputSize,
    ]);
    final runOptions = OrtRunOptions();
    try {
      final outputs = await session.runAsync(runOptions, <String, OrtValue>{
        'images': inputValue,
      });
      if (outputs == null || outputs.isEmpty) return null;
      final first = outputs.first;
      final flat = first == null ? null : _flatten(first.value);
      for (final o in outputs) {
        o?.release();
      }
      return flat;
    } finally {
      inputValue.release();
      runOptions.release();
    }
  }

  /// Flattens the nested [1][56][8400] list returned by ONNX Runtime.
  static Float32List? _flatten(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final batch = value.first;
    if (batch is! List) return null;
    final out = Float32List(YoloPoseCodec.channels * YoloPoseCodec.anchors);
    var offset = 0;
    for (final row in batch) {
      if (row is! List) return null;
      for (final v in row) {
        if (offset >= out.length || v is! num) return null;
        out[offset++] = v.toDouble();
      }
    }
    return offset == out.length ? out : null;
  }

  /// Buffers the frame; when a window is due, runs the DSP + features in a
  /// background isolate, then LightGBM (sub-millisecond) on this isolate.
  void _updateFogWindow(List<Keypoint2D> keypoints) {
    final snapshot = _fog.pushSnapshot(keypoints);
    if (snapshot == null) return;
    if (_dspBusy) {
      // Previous window still computing (> 1 s): skip rather than queue up.
      if (kDebugMode) debugPrint('FoG DSP still busy; window skipped.');
      return;
    }
    _dspBusy = true;
    final generation = _generation;
    unawaited(
      _computeFogWindowInIsolate(snapshot)
          .then((window) => _applyFogWindow(window, generation))
          .catchError((Object error) {
            if (kDebugMode) debugPrint('FoG DSP failed: $error');
          })
          .whenComplete(() {
            if (generation == _generation) _dspBusy = false;
          }),
    );
  }

  void _applyFogWindow(FogWindowFeatures window, int generation) {
    if (generation != _generation) return;
    final p = _classifier.predict(window.features);
    if (p == null) return;
    _latestProb = p;
    _latestFreezeIndex = window.freezeIndexAnkle;
    _latestWindowLowQuality =
        window.isLowQuality || (_fpsEma > 0 && _fpsEma < _minReliableFps);
  }

  // Static so the isolate closures capture only their argument, never `this`.
  static Future<YoloInput> _preprocessInIsolate(YuvFrame frame) =>
      Isolate.run(() => YoloPoseCodec.preprocess(frame));

  static Future<FogWindowFeatures> _computeFogWindowInIsolate(
    FogWindowSnapshot snapshot,
  ) => Isolate.run(() => FogFeatureExtractor.computeWindow(snapshot));

  LiveFrameResult _buildResult(
    List<Keypoint2D> keypoints,
    LetterboxMeta meta,
    int startedMs,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastProcessedMs > 0) {
      final instantFps = 1000 / (now - _lastProcessedMs).clamp(1, 10000);
      _fpsEma = _fpsEma == 0 ? instantFps : _fpsEma * 0.8 + instantFps * 0.2;
    }
    _lastProcessedMs = startedMs;
    _seq++;

    var confSum = 0.0;
    for (final i in _lb6Indices) {
      confSum += keypoints[i].conf;
    }
    final lb6AvgConf = confSum / _lb6Indices.length;

    return LiveFrameResult(
      sequenceId: _seq,
      timestampMs: now,
      imageWidth: meta.imageWidth.toDouble(),
      imageHeight: meta.imageHeight.toDouble(),
      keypoints17: keypoints,
      lb6AvgConf: lb6AvgConf,
      effectiveFps: _fpsEma,
      rawProb: _latestProb,
      thresholdUsed: OnnxFogClassifier.threshold,
      freezeIndex: _latestFreezeIndex,
      isLowQualityWindow:
          _latestWindowLowQuality || lb6AvgConf < Keypoint2D.confValidThreshold,
    );
  }

  static YuvFrame _copyFrame(CameraImage image, int rotationDegrees) {
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    return YuvFrame(
      width: image.width,
      height: image.height,
      yBytes: Uint8List.fromList(y.bytes),
      uBytes: Uint8List.fromList(u.bytes),
      vBytes: Uint8List.fromList(v.bytes),
      yRowStride: y.bytesPerRow,
      uvRowStride: u.bytesPerRow,
      uvPixelStride: u.bytesPerPixel ?? 1,
      rotationDegrees: rotationDegrees,
    );
  }

  Future<void> _stopCameraAndClose() async {
    final camera = _camera.value;
    _camera.value = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    if (camera == null) return;
    // Let the UI drop its CameraPreview before the controller is disposed.
    await SchedulerBinding.instance.endOfFrame;
    if (camera.value.isStreamingImages) {
      await camera.stopImageStream();
    }
    await camera.dispose();
  }

  static final List<Keypoint2D> _emptyKeypoints = List<Keypoint2D>.unmodifiable(
    List<Keypoint2D>.filled(
      YoloPoseCodec.keypointCount,
      const Keypoint2D(x: 0, y: 0, conf: 0),
    ),
  );
}
