import 'dart:async';
import 'dart:math' as math;

import '../../application/ports/edge_inference_port.dart';
import '../../domain/entities/live_frame_result.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/value_objects/keypoint_2d.dart';

/// Deterministic 15 Hz synthetic 17-COCO pose inference preview adapter allowing
/// interactive end-to-end verification of S-05..S-08 prior to native camera FFI.
class PreviewPoseInferenceAdapter implements EdgeInferencePort {
  StreamController<LiveFrameResult>? _controller;
  Timer? _timer;
  int _seq = 0;
  PreviewGaitScenario _scenario = PreviewGaitScenario.normalGait;

  @override
  bool get isPreviewSimulation => true;

  @override
  Stream<LiveFrameResult> startLiveStream({required MedicationState medState}) {
    _cancelTimerAndClose();
    _scenario = PreviewGaitScenario.normalGait;
    _seq = 0;
    final controller = StreamController<LiveFrameResult>.broadcast();
    _controller = controller;

    // Emit initial frame asynchronously right away so framing HUD renders immediately.
    Future<void>.microtask(() {
      if (!controller.isClosed) {
        controller.add(_buildFrame());
      }
    });

    _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!controller.isClosed) {
        controller.add(_buildFrame());
      }
    });
    return controller.stream;
  }

  @override
  void setPreviewScenario(PreviewGaitScenario scenario) {
    _scenario = scenario;
  }

  @override
  Future<void> stopLiveStream() async {
    _cancelTimerAndClose();
  }

  void _cancelTimerAndClose() {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  Future<void> secureDeleteTempVideo() async {
    // Preview mode runs strictly on synthetic keypoint coordinates without temp video files.
  }

  void dispose() {
    unawaited(stopLiveStream());
  }

  LiveFrameResult _buildFrame() {
    _seq++;
    const imgW = 480.0;
    const imgH = 640.0;
    final t = _seq / 15.0;

    final double swing;
    final double lb6Conf;
    final double rawProb;
    final double freezeIndex;
    final double hipDropOffset;
    final double hipDropRatio;
    final bool isImmobile;
    final bool lowQuality;

    switch (_scenario) {
      case PreviewGaitScenario.normalGait:
        swing = math.sin(t * 2.8) * 26.0;
        lb6Conf = 0.94;
        rawProb = 0.08 + 0.03 * math.sin(t * 1.3);
        freezeIndex = 0.42;
        hipDropOffset = 0.0;
        hipDropRatio = 0.0;
        isImmobile = false;
        lowQuality = false;
      case PreviewGaitScenario.lowLightOcclusion:
        swing = 2.0;
        lb6Conf = 0.12;
        rawProb = 0.08;
        freezeIndex = 0.30;
        hipDropOffset = 0.0;
        hipDropRatio = 0.0;
        isImmobile = true;
        lowQuality = true;
      case PreviewGaitScenario.confirmedFog:
        // High-frequency 5 Hz small ankle trembling characteristic of FoG
        swing = math.sin(t * 32.0) * 5.0;
        lb6Conf = 0.89;
        rawProb = 0.64;
        freezeIndex = 2.41;
        hipDropOffset = 0.0;
        hipDropRatio = 0.0;
        isImmobile = false;
        lowQuality = false;
      case PreviewGaitScenario.suddenFall:
        swing = 0.0;
        lb6Conf = 0.84;
        rawProb = 0.72;
        freezeIndex = 3.10;
        hipDropOffset = 110.0;
        hipDropRatio = 0.78;
        isImmobile = true;
        lowQuality = false;
    }

    final hipY = 330.0 + hipDropOffset;
    final kneeY = 445.0 + hipDropOffset * 0.6;
    final ankleY = 560.0 + hipDropOffset * 0.2;
    final upperConf = _scenario == PreviewGaitScenario.lowLightOcclusion
        ? 0.45
        : 0.96;

    final kps = <Keypoint2D>[
      Keypoint2D(x: 240, y: 120 + hipDropOffset, conf: upperConf), // 0 nose
      Keypoint2D(x: 230, y: 112 + hipDropOffset, conf: upperConf), // 1 L_Eye
      Keypoint2D(x: 250, y: 112 + hipDropOffset, conf: upperConf), // 2 R_Eye
      Keypoint2D(x: 218, y: 118 + hipDropOffset, conf: upperConf), // 3 L_Ear
      Keypoint2D(x: 262, y: 118 + hipDropOffset, conf: upperConf), // 4 R_Ear
      Keypoint2D(
        x: 196,
        y: 185 + hipDropOffset,
        conf: upperConf,
      ), // 5 L_Shoulder
      Keypoint2D(
        x: 284,
        y: 185 + hipDropOffset,
        conf: upperConf,
      ), // 6 R_Shoulder
      Keypoint2D(x: 176, y: 260 + hipDropOffset, conf: upperConf), // 7 L_Elbow
      Keypoint2D(x: 304, y: 260 + hipDropOffset, conf: upperConf), // 8 R_Elbow
      Keypoint2D(x: 170, y: 325 + hipDropOffset, conf: upperConf), // 9 L_Wrist
      Keypoint2D(x: 310, y: 325 + hipDropOffset, conf: upperConf), // 10 R_Wrist
      // LB6 Lower Body Keypoints (11..16)
      Keypoint2D(x: 210, y: hipY, conf: lb6Conf), // 11 L_Hip
      Keypoint2D(x: 270, y: hipY, conf: lb6Conf), // 12 R_Hip
      Keypoint2D(x: 204 + swing * 0.5, y: kneeY, conf: lb6Conf), // 13 L_Knee
      Keypoint2D(x: 276 - swing * 0.5, y: kneeY, conf: lb6Conf), // 14 R_Knee
      Keypoint2D(x: 200 + swing, y: ankleY, conf: lb6Conf), // 15 L_Ankle
      Keypoint2D(x: 280 - swing, y: ankleY, conf: lb6Conf), // 16 R_Ankle
    ];

    return LiveFrameResult(
      sequenceId: _seq,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      imageWidth: imgW,
      imageHeight: imgH,
      keypoints17: List<Keypoint2D>.unmodifiable(kps),
      lb6AvgConf: lb6Conf,
      effectiveFps: 15.0,
      rawProb: rawProb,
      freezeIndex: freezeIndex,
      isLowQualityWindow: lowQuality,
      hipDropRatio: hipDropRatio,
      isImmobile: isImmobile,
    );
  }
}
