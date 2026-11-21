import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/clinical_session_providers.dart';

/// Upright back-camera frame filling its parent with `BoxFit.cover`, matching
/// `CameraCoordinateMapper` so the skeleton HUD lines up with the body.
///
/// Shows the frame the current skeleton was detected on rather than a live
/// `CameraPreview`, so picture and skeleton are always in sync.
/// Renders nothing in synthetic preview mode or before the first frame.
class LiveCameraBackdrop extends ConsumerWidget {
  const LiveCameraBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listenable = ref.watch(liveAnalyzedFrameProvider);
    if (listenable == null) return const SizedBox.shrink();

    return ValueListenableBuilder<ui.Image?>(
      valueListenable: listenable,
      builder: (context, image, _) {
        if (image == null) return const SizedBox.shrink();
        return ExcludeSemantics(
          child: ClipRect(
            child: RawImage(
              image: image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          ),
        );
      },
    );
  }
}
