import 'dart:math' as math;
import 'dart:ui';

/// Pure coordinate projector mapping camera sensor keypoints `(x_img, y_img)`
/// onto a `BoxFit.cover` Flutter canvas, handling 90/270 sensor rotation and
/// front-camera horizontal mirroring per `hud_and_cueing_contract.md`.
class CameraCoordinateMapper {
  const CameraCoordinateMapper({
    required this.imageWidth,
    required this.imageHeight,
    required this.viewWidth,
    required this.viewHeight,
    this.isFrontCameraMirrored = false,
    this.sensorRotationDegrees = 0,
  });

  final double imageWidth;
  final double imageHeight;
  final double viewWidth;
  final double viewHeight;
  final bool isFrontCameraMirrored;
  final int sensorRotationDegrees;

  Offset mapPoint(double xImg, double yImg) {
    if (imageWidth <= 0 || imageHeight <= 0 || viewWidth <= 0 || viewHeight <= 0) {
      return Offset.zero;
    }

    final swapped =
        sensorRotationDegrees == 90 || sensorRotationDegrees == 270;
    final effW = swapped ? imageHeight : imageWidth;
    final effH = swapped ? imageWidth : imageHeight;

    final scale = math.max(viewWidth / effW, viewHeight / effH);
    final drawnW = effW * scale;
    final drawnH = effH * scale;
    final dx = (viewWidth - drawnW) * 0.5;
    final dy = (viewHeight - drawnH) * 0.5;

    var screenX = xImg * scale + dx;
    if (isFrontCameraMirrored) {
      screenX = viewWidth - screenX;
    }
    final screenY = yImg * scale + dy;
    return Offset(screenX, screenY);
  }
}
