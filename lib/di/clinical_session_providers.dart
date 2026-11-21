import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/controllers/clinical_session_coordinator.dart';
import '../application/controllers/clinical_session_ui_state.dart';
import '../application/ports/edge_inference_port.dart';
import '../application/ports/emergency_alert_port.dart';
import '../domain/enums/medication_state.dart';
import '../domain/enums/preview_gait_scenario.dart';
import '../infrastructure/cueing/local_emergency_alert_adapter.dart';
import '../infrastructure/edge_ai/onnx_pose_inference_adapter.dart';
import '../infrastructure/edge_ai/preview_pose_inference_adapter.dart';
import 'dashboard_providers.dart';
import 'onboarding_providers.dart';
import 'session_prep_providers.dart';

final previewPoseAdapterProvider = Provider<PreviewPoseInferenceAdapter>((ref) {
  final adapter = PreviewPoseInferenceAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// Selects the edge inference backend at build time:
/// `--dart-define=PARKIN_EDGE_MODE=onnx` runs the on-device YOLO pose model,
/// anything else keeps the deterministic synthetic preview.
const String _edgeMode = String.fromEnvironment('PARKIN_EDGE_MODE');

final onnxPoseAdapterProvider = Provider<OnnxPoseInferenceAdapter>((ref) {
  final adapter = OnnxPoseInferenceAdapter();
  ref.onDispose(() => unawaited(adapter.dispose()));
  return adapter;
});

/// Last analysed camera frame (the one the skeleton was detected on);
/// `null` in synthetic preview mode.
final liveAnalyzedFrameProvider = Provider<ValueListenable<ui.Image?>?>(
  (ref) => _edgeMode == 'onnx'
      ? ref.watch(onnxPoseAdapterProvider).analyzedFrame
      : null,
);

final edgeInferencePortProvider = Provider<EdgeInferencePort>(
  (ref) => _edgeMode == 'onnx'
      ? ref.watch(onnxPoseAdapterProvider)
      : ref.watch(previewPoseAdapterProvider),
);

final emergencyAlertPortProvider = Provider<EmergencyAlertPort>(
  (ref) => const LocalEmergencyAlertAdapter(),
);

/// Riverpod 3 Notifier binding ClinicalSessionCoordinator (S-05..S-08) to UI.
class ClinicalSessionController extends Notifier<ClinicalSessionUiState> {
  late ClinicalSessionCoordinator _coordinator;

  @override
  ClinicalSessionUiState build() {
    _coordinator = ClinicalSessionCoordinator(
      edgeInferencePort: ref.read(edgeInferencePortProvider),
      cueingPort: ref.read(cueingPortProvider),
      voiceGuidePort: ref.read(voiceGuideProvider),
      emergencyAlertPort: ref.read(emergencyAlertPortProvider),
      dashboardRepository: ref.read(homeDashboardRepositoryProvider),
      patientNameReader: () =>
          ref.read(onboardingControllerProvider).status.displayName,
      readState: () => state,
      writeState: (next) => state = next,
    );
    ref.onDispose(_coordinator.cancelTimersAndStreamsOnly);
    return ClinicalSessionUiState(
      isPreviewSimulation: ref
          .read(edgeInferencePortProvider)
          .isPreviewSimulation,
    );
  }

  Future<void> startSession({required MedicationState medState}) =>
      _coordinator.startSession(medState: medState);

  void retryCalibration() => _coordinator.retryCalibration();

  void cancelFallGuard() => _coordinator.cancelFallGuard();

  void triggerEmergencyNow() => _coordinator.triggerEmergencyNow();

  void finishSessionEarly() => _coordinator.finishSessionEarly();

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
