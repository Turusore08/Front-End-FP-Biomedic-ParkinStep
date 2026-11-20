import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/live_frame_result.dart';
import '../../../../domain/enums/alert_tier.dart';
import '../../../theme/app_colors.dart';
import '../mappers/camera_coordinate_mapper.dart';

/// 60 FPS `CustomPainter` rendering 17 COCO keypoints with thin `#38BDF8`
/// upper-body bones (`2.0 dp`) and bold state-colored LB6 lower-body highlight (`4.0 dp`).
class SkeletonHudPainter extends CustomPainter {
  const SkeletonHudPainter({
    required this.frame,
    required this.alertTier,
    this.isFrontCameraMirrored = false,
  });

  final LiveFrameResult? frame;
  final AlertTier alertTier;
  final bool isFrontCameraMirrored;

  static const List<(int, int)> _upperBones = <(int, int)>[
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 4),
    (5, 6),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 11),
    (6, 12),
  ];

  static const List<(int, int)> _lb6Bones = <(int, int)>[
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
  ];

  static const List<int> _lb6Joints = <int>[11, 12, 13, 14, 15, 16];

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame;
    if (current == null || current.keypoints17.length < 17) return;

    final mapper = CameraCoordinateMapper(
      imageWidth: current.imageWidth,
      imageHeight: current.imageHeight,
      viewWidth: size.width,
      viewHeight: size.height,
      isFrontCameraMirrored: isFrontCameraMirrored,
    );

    final lb6Color = switch (alertTier) {
      AlertTier.gaitNormal => AppColors.normalEmerald,
      AlertTier.earlyWarning => AppColors.warningAmber,
      AlertTier.fogConfirmed => AppColors.alertRed,
      AlertTier.fallGuard => AppColors.alertRed,
    };

    final upperPaint = Paint()
      ..color = AppColors.upperBodySky.withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in _upperBones) {
      final kpA = current.keypoints17[a];
      final kpB = current.keypoints17[b];
      if (!kpA.isValid || !kpB.isValid) continue;
      canvas.drawLine(
        mapper.mapPoint(kpA.x, kpA.y),
        mapper.mapPoint(kpB.x, kpB.y),
        upperPaint,
      );
    }

    final lb6Paint = Paint()
      ..color = lb6Color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in _lb6Bones) {
      final kpA = current.keypoints17[a];
      final kpB = current.keypoints17[b];
      if (!kpA.isValid || !kpB.isValid) continue;
      canvas.drawLine(
        mapper.mapPoint(kpA.x, kpA.y),
        mapper.mapPoint(kpB.x, kpB.y),
        lb6Paint,
      );
    }

    final outerJointPaint = Paint()
      ..color = AppColors.pureWhite
      ..style = PaintingStyle.fill;
    final innerJointPaint = Paint()
      ..color = lb6Color
      ..style = PaintingStyle.fill;

    for (final idx in _lb6Joints) {
      final kp = current.keypoints17[idx];
      if (!kp.isValid) continue;
      final pt = mapper.mapPoint(kp.x, kp.y);
      canvas.drawCircle(pt, 6.5, outerJointPaint);
      canvas.drawCircle(pt, 4.5, innerJointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonHudPainter oldDelegate) {
    return oldDelegate.frame?.sequenceId != frame?.sequenceId ||
        oldDelegate.alertTier != alertTier ||
        oldDelegate.isFrontCameraMirrored != isFrontCameraMirrored;
  }
}
