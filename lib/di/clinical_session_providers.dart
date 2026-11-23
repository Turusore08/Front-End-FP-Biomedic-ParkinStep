import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/controllers/clinical_session_coordinator.dart';
import '../application/controllers/clinical_session_ui_state.dart';
import '../application/ports/video_session_port.dart';
import '../domain/enums/medication_state.dart';
import '../domain/enums/preview_gait_scenario.dart';
import '../domain/enums/session_protocol.dart';
import '../infrastructure/edge_ai/onnx_video_session_adapter.dart';
import '../infrastructure/edge_ai/preview_video_session_adapter.dart';
import 'dashboard_providers.dart';
import 'onboarding_providers.dart';
import 'session_prep_providers.dart';
import 'video_playback_providers.dart';

final previewVideoSessionAdapterProvider = Provider<PreviewVideoSessionAdapter>(
  (ref) => PreviewVideoSessionAdapter(),
);

/// Selects the edge inference backend at build time:
/// `--dart-define=PARKIN_EDGE_MODE=onnx` records video and extracts poses
/// with `yolo26n-pose.onnx` + `lgbm_b15hz.onnx` after user submits;
/// anything else keeps the deterministic synthetic preview.
const String _edgeMode = String.fromEnvironment('PARKIN_EDGE_MODE');

final onnxVideoSessionAdapterProvider = Provider<OnnxVideoSessionAdapter>((ref) {
  final adapter = OnnxVideoSessionAdapter();
  ref.onDispose(() => unawaited(adapter.dispose()));
  return adapter;
});

/// Live back-camera controller for `CameraPreview`; `null` in synthetic preview mode.
final liveCameraControllerProvider =
    Provider<ValueListenable<CameraController?>?>(
      (ref) => _edgeMode == 'onnx'
          ? ref.watch(onnxVideoSessionAdapterProvider).cameraController
          : null,
    );

final videoSessionPortProvider = Provider<VideoSessionPort>(
  (ref) => _edgeMode == 'onnx'
      ? ref.watch(onnxVideoSessionAdapterProvider)
      : ref.watch(previewVideoSessionAdapterProvider),
);

/// Riverpod 3 Notifier binding video ClinicalSessionCoordinator to UI.
class ClinicalSessionController extends Notifier<ClinicalSessionUiState> {
  late ClinicalSessionCoordinator _coordinator;

  @override
  ClinicalSessionUiState build() {
    _coordinator = ClinicalSessionCoordinator(
      videoSessionPort: ref.read(videoSessionPortProvider),
      recordedMediaPort: ref.read(recordedMediaPortProvider),
      cueingPort: ref.read(cueingPortProvider),
      voiceGuidePort: ref.read(voiceGuideProvider),
      dashboardRepository: ref.read(homeDashboardRepositoryProvider),
      patientNameReader: () =>
          ref.read(onboardingControllerProvider).status.displayName,
      readState: () => state,
      writeState: (next) => state = next,
    );
    ref.onDispose(_coordinator.cancelTimersAndStreamsOnly);
    return ClinicalSessionUiState(
      isPreviewSimulation:
          ref.read(videoSessionPortProvider).isPreviewSimulation,
    );
  }

  Future<void> startSession({
    required SessionProtocol protocol,
    required MedicationState medState,
  }) =>
      _coordinator.startSession(protocol: protocol, medState: medState);

  void startCountdown() => _coordinator.startCountdown();

  void stopRecording() => _coordinator.stopRecording();

  Future<void> retakeRecording() => _coordinator.retakeRecording();

  Future<void> submitVideoForAnalysis() =>
      _coordinator.submitVideoForAnalysis();

  Future<void> cancelAnalysis() => _coordinator.cancelAnalysis();

  Future<void> deleteCompletedSessionVideo() =>
      _coordinator.deleteCompletedSessionVideo();

  void toggleSound() => _coordinator.toggleSound();

  void setPreviewScenario(PreviewGaitScenario scenario) =>
      _coordinator.setPreviewScenario(scenario);

  void handleLifecyclePaused() => _coordinator.handleLifecyclePaused();

  void cancelTimersAndStreamsOnly() =>
      _coordinator.cancelTimersAndStreamsOnly();
}

final clinicalSessionControllerProvider =
    NotifierProvider<ClinicalSessionController, ClinicalSessionUiState>(
      ClinicalSessionController.new,
    );
