import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../domain/enums/session_protocol.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Translucent visual framing box over the camera preview guiding the patient
/// and caregiver where to stand so the full body (head-to-ankle) stays within
/// optimal YOLO & gait-screening distance (not too close, not too far).
///
/// Pure visual overlay (`IgnorePointer`) - performs zero ML inference.
class CameraStandingGuideOverlay extends StatelessWidget {
  const CameraStandingGuideOverlay({
    super.key,
    required this.protocol,
    this.isRecording = false,
    this.topInsetFactor = 0.13,
    this.bottomInsetFactor = 0.39,
  });

  final SessionProtocol protocol;
  final bool isRecording;
  final double topInsetFactor;
  final double bottomInsetFactor;

  /// Computes the centered safe framing rectangle inside [size], reserving top
  /// toolbar/badge space and bottom card/button controls.
  static Rect computeGuideRect(
    Size size, {
    required SessionProtocol protocol,
    required double topInsetFactor,
    required double bottomInsetFactor,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return Rect.zero;
    }
    final safeTop = (size.height * topInsetFactor).clamp(0.0, size.height * 0.40);
    final minHeight = math.min(120.0, size.height - safeTop);
    final safeBottom = (size.height * (1.0 - bottomInsetFactor)).clamp(
      safeTop + minHeight,
      size.height,
    );
    final guideH = (safeBottom - safeTop).clamp(1.0, size.height);
    final isWalking = protocol == SessionProtocol.walkBackAndForth;
    final maxW = math.max(1.0, size.width - 24.0);
    final minW = math.min(maxW, isWalking ? 180.0 : 160.0);
    final desiredW = math.min(
      size.width * (isWalking ? 0.78 : 0.68),
      guideH * (isWalking ? 0.95 : 0.72),
    );
    final guideW = desiredW.clamp(minW, maxW);
    final left = (size.width - guideW) / 2.0;
    return Rect.fromLTWH(left, safeTop, guideW, guideH);
  }

  /// Protocol-tailored Indonesian framing hint shown before recording starts.
  static String distanceHintFor(SessionProtocol protocol) {
    switch (protocol) {
      case SessionProtocol.turning360:
        return 'Berdiri di dalam kotak (2-3 m)';
      case SessionProtocol.walkBackAndForth:
        return 'Posisikan tubuh di kotak (2-3 m)';
      case SessionProtocol.sitToStand:
        return 'Kursi & tubuh di kotak (2-3 m)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final size = constraints.biggest;
          final guideRect = computeGuideRect(
            size,
            protocol: protocol,
            topInsetFactor: topInsetFactor,
            bottomInsetFactor: bottomInsetFactor,
          );
          if (guideRect.isEmpty) {
            return const SizedBox.shrink();
          }

          final innerWidth = math.max(0.0, guideRect.width - 16.0);

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('camera_standing_guide_paint'),
                    painter: _CameraStandingGuidePainter(
                      guideRect: guideRect,
                      isRecording: isRecording,
                    ),
                  ),
                ),
              ),
              if (!isRecording) ...[
                Positioned(
                  top: guideRect.top + 8,
                  left: guideRect.left + 8,
                  width: innerWidth,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        key: const Key('standing_guide_distance_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.midnightNavy.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.skyCard.withValues(alpha: 0.75),
                          ),
                        ),
                        child: Text(
                          distanceHintFor(protocol),
                          style: AppTypography.captionBadge(
                            color: AppColors.pureWhite,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: math.max(guideRect.top + 36, guideRect.bottom - 36),
                  left: guideRect.left + 8,
                  width: innerWidth,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        key: const Key('standing_guide_feet_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.midnightNavy.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.normalEmerald),
                        ),
                        child: Text(
                          'Batas Kaki · Kepala-Kaki Penuh',
                          style: AppTypography.captionBadge(
                            color: AppColors.emeraldSoftBg,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CameraStandingGuidePainter extends CustomPainter {
  const _CameraStandingGuidePainter({
    required this.guideRect,
    required this.isRecording,
  });

  final Rect guideRect;
  final bool isRecording;

  @override
  void paint(Canvas canvas, Size size) {
    if (guideRect.isEmpty) return;

    const radius = Radius.circular(22);
    final guideRRect = RRect.fromRectAndRadius(guideRect, radius);

    // 1. Subtle outer dimming scrim outside the safe standing zone
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addRRect(guideRRect);
    final scrimPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(
      scrimPath,
      Paint()
        ..color = AppColors.midnightNavy.withValues(
          alpha: isRecording ? 0.16 : 0.34,
        )
        ..style = PaintingStyle.fill,
    );

    // 2. Dashed outer box outline
    _drawDashedPath(
      canvas,
      holePath,
      Paint()
        ..color = AppColors.skyCard.withValues(alpha: isRecording ? 0.50 : 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
      dashLength: 10,
      gapLength: 7,
    );

    // 3. 4 high-contrast L-corner brackets
    final bracketLen = math.min(26.0, guideRect.shortestSide * 0.25);
    final bracketPaint = Paint()
      ..color = isRecording
          ? AppColors.skyCard.withValues(alpha: 0.78)
          : AppColors.rhythmAqua
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRecording ? 3.0 : 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final l = guideRect.left;
    final t = guideRect.top;
    final r = guideRect.right;
    final b = guideRect.bottom;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + bracketLen)
        ..lineTo(l, t + 6)
        ..quadraticBezierTo(l, t, l + 6, t)
        ..lineTo(l + bracketLen, t),
      bracketPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(r - bracketLen, t)
        ..lineTo(r - 6, t)
        ..quadraticBezierTo(r, t, r, t + 6)
        ..lineTo(r, t + bracketLen),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(l, b - bracketLen)
        ..lineTo(l, b - 6)
        ..quadraticBezierTo(l, b, l + 6, b)
        ..lineTo(l + bracketLen, b),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(r - bracketLen, b)
        ..lineTo(r - 6, b)
        ..quadraticBezierTo(r, b, r, b - 6)
        ..lineTo(r, b - bracketLen),
      bracketPaint,
    );

    // 4. Inner head alignment dashed line
    final headY = t + guideRect.height * 0.16;
    _drawDashedSegment(
      canvas,
      Offset(l + 16, headY),
      Offset(r - 16, headY),
      Paint()
        ..color = AppColors.skyCard.withValues(alpha: isRecording ? 0.32 : 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
      dashLength: 7,
      gapLength: 6,
    );

    // 5. Subtle translucent standing posture silhouette (pre-recording only)
    final footY = isRecording
        ? b - guideRect.height * 0.12
        : math.max(t + guideRect.height * 0.55, b - math.max(42.0, guideRect.height * 0.15));
    if (!isRecording) {
      _drawStandingSilhouette(canvas, footY: footY);
    }

    // 6. Emerald foot/ankle boundary dashed line with end ticks
    final footPaint = Paint()
      ..color = AppColors.normalEmerald.withValues(
        alpha: isRecording ? 0.55 : 0.90,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    _drawDashedSegment(
      canvas,
      Offset(l + 14, footY),
      Offset(r - 14, footY),
      footPaint,
      dashLength: 9,
      gapLength: 5,
    );
    canvas.drawLine(
      Offset(l + 14, footY - 4),
      Offset(l + 14, footY + 4),
      footPaint,
    );
    canvas.drawLine(
      Offset(r - 14, footY - 4),
      Offset(r - 14, footY + 4),
      footPaint,
    );
  }

  void _drawStandingSilhouette(Canvas canvas, {required double footY}) {
    final cx = guideRect.center.dx;
    final h = guideRect.height;
    final bodyW = math.min(guideRect.width * 0.34, h * 0.24);
    final headR = math.max(8.0, h * 0.055);
    final headCenterY = guideRect.top + h * 0.24;
    final shoulderY = headCenterY + headR + h * 0.04;
    final hipY = guideRect.top + h * 0.56;

    final silhouettePaint = Paint()
      ..color = AppColors.pureWhite.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, headCenterY),
        width: headR * 1.75,
        height: headR * 2.05,
      ),
      silhouettePaint,
    );

    // Shoulders and torso contour
    final torsoPath = Path()
      ..moveTo(cx - bodyW * 0.72, shoulderY + 6)
      ..quadraticBezierTo(cx, shoulderY - 4, cx + bodyW * 0.72, shoulderY + 6)
      ..moveTo(cx - bodyW * 0.48, shoulderY + 4)
      ..lineTo(cx - bodyW * 0.36, hipY)
      ..lineTo(cx + bodyW * 0.36, hipY)
      ..lineTo(cx + bodyW * 0.48, shoulderY + 4);
    canvas.drawPath(torsoPath, silhouettePaint);

    // Two standing legs aligned to foot boundary line
    canvas.drawLine(
      Offset(cx - bodyW * 0.22, hipY),
      Offset(cx - bodyW * 0.28, footY - 2),
      silhouettePaint,
    );
    canvas.drawLine(
      Offset(cx + bodyW * 0.22, hipY),
      Offset(cx + bodyW * 0.28, footY - 2),
      silhouettePaint,
    );
  }

  void _drawDashedSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final total = (end - start).distance;
    if (total <= 0) return;
    final dir = (end - start) / total;
    var dist = 0.0;
    while (dist < total) {
      final segEnd = math.min(dist + dashLength, total);
      canvas.drawLine(start + dir * dist, start + dir * segEnd, paint);
      dist += dashLength + gapLength;
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CameraStandingGuidePainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.isRecording != isRecording;
  }
}
