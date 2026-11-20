import '../../domain/entities/live_frame_result.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/preview_gait_scenario.dart';

/// Gateway producing real-time 15 Hz 17-COCO pose frames and handling secure cleanup.
abstract interface class EdgeInferencePort {
  bool get isPreviewSimulation;

  Stream<LiveFrameResult> startLiveStream({
    required MedicationState medState,
  });

  void setPreviewScenario(PreviewGaitScenario scenario);

  Future<void> stopLiveStream();

  Future<void> secureDeleteTempVideo();
}
