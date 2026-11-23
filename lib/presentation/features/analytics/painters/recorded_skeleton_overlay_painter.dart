import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/recorded_pose_track.dart';
import '../../../../domain/value_objects/keypoint_2d.dart';
import '../../../theme/app_colors.dart';

/// Draws all 17 COCO skeleton keypoints synchronized with the recorded video frame
/// using `BoxFit.contain` projection so joints stay pixel-aligned over the body.
class RecordedSkeletonOverlayPainter extends CustomPainter {
  const RecordedSkeletonOverlayPainter({
    required this.frame,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.isFogActive,
  });

  final TimedPoseFrame? frame;
  final double sourceWidth;
  final double sourceHeight;
  final bool isFogActive;

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

  static const List<int> _upperJoints = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  static const List<int> _lb6Joints = <int>[11, 12, 13, 14, 15, 16];

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame;
    if (current == null || current.keypoints17.length < 17) return;
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final scale = math.min(size.width / sourceWidth, size.height / sourceHeight);
    final drawnW = sourceWidth * scale;
    final drawnH = sourceHeight * scale;
    final dx = (size.width - drawnW) * 0.5;
    final dy = (size.height - drawnH) * 0.5;

    Offset mapPoint(Keypoint2D kp) => Offset(kp.x * scale + dx, kp.y * scale + dy);

    final lb6Color = isFogActive ? AppColors.alertRed : AppColors.normalEmerald;

    final upperBonePaint = Paint()
      ..color = AppColors.upperBodySky.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in _upperBones) {
      final kpA = current.keypoints17[a];
      final kpB = current.keypoints17[b];
      if (!kpA.isValid || !kpB.isValid) continue;
      canvas.drawLine(mapPoint(kpA), mapPoint(kpB), upperBonePaint);
    }

    final upperDotPaint = Paint()
      ..color = AppColors.upperBodySky
      ..style = PaintingStyle.fill;
    for (final idx in _upperJoints) {
      final kp = current.keypoints17[idx];
      if (!kp.isValid) continue;
      canvas.drawCircle(mapPoint(kp), 3.5, upperDotPaint);
    }

    final lb6Paint = Paint()
      ..color = lb6Color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in _lb6Bones) {
      final kpA = current.keypoints17[a];
      final kpB = current.keypoints17[b];
      if (!kpA.isValid || !kpB.isValid) continue;
      canvas.drawLine(mapPoint(kpA), mapPoint(kpB), lb6Paint);
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
      final pt = mapPoint(kp);
      canvas.drawCircle(pt, 6.5, outerJointPaint);
      canvas.drawCircle(pt, 4.5, innerJointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RecordedSkeletonOverlayPainter oldDelegate) {
    return oldDelegate.frame?.timestampMs != frame?.timestampMs ||
        oldDelegate.sourceWidth != sourceWidth ||
        oldDelegate.sourceHeight != sourceHeight ||
        oldDelegate.isFogActive != isFogActive;
  }
}
