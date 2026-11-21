import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/clinical_session_providers.dart';

/// Upright back-camera feed filling its parent with `BoxFit.cover`, matching
/// `CameraCoordinateMapper` so the skeleton HUD lines up with the body.
/// Renders nothing in synthetic preview mode or before the camera is ready.
class LiveCameraBackdrop extends ConsumerWidget {
  const LiveCameraBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listenable = ref.watch(liveCameraControllerProvider);
    if (listenable == null) return const SizedBox.shrink();

    return ValueListenableBuilder<CameraController?>(
      valueListenable: listenable,
      builder: (context, camera, _) {
        if (camera == null || !camera.value.isInitialized) {
          return const SizedBox.shrink();
        }
        final previewSize = camera.value.previewSize;
        if (previewSize == null) return const SizedBox.shrink();

        // previewSize is reported in sensor (landscape) orientation; the
        // portrait preview is its transpose.
        final uprightW = previewSize.shortestSide;
        final uprightH = previewSize.longestSide;

        return ExcludeSemantics(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: uprightW,
                height: uprightH,
                child: CameraPreview(camera),
              ),
            ),
          ),
        );
      },
    );
  }
}
