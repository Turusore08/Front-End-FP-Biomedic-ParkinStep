import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Tick-marked 150-degree semicircle FoG risk gauge mapping calibrated risk
/// score (`0..100%`, where `50% == thr_val`) with accessible 14 sp labels.
class ParkinRiskGauge extends StatelessWidget {
  const ParkinRiskGauge({
    super.key,
    required this.calibratedRiskScore,
    this.onDarkSurface = false,
  });

  final double calibratedRiskScore;
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) {
    final score = calibratedRiskScore.isFinite
        ? calibratedRiskScore.clamp(0.0, 100.0)
        : 0.0;
    final valueColor = onDarkSurface ? AppColors.pureWhite : AppColors.royalNavy;
    final captionColor =
        onDarkSurface ? AppColors.darkMuted : AppColors.mutedSlate;

    return Semantics(
      label: 'Skor risiko FoG terkalibrasi ${score.round()} persen',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(280.0, constraints.maxWidth).clamp(180.0, 280.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: 126,
                child: CustomPaint(
                  painter: _RiskGaugePainter(
                    score: score,
                    onDarkSurface: onDarkSurface,
                  ),
                ),
              ),
              Text(
                '${score.round()}%',
                style: AppTypography.heroMetric(color: valueColor, size: 24),
              ),
              Text(
                'Skor Risiko FoG (Ambang 50%)',
                textAlign: TextAlign.center,
                style: AppTypography.captionBadge(
                  color: captionColor,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  const _RiskGaugePainter({
    required this.score,
    required this.onDarkSurface,
  });

  final double score;
  final bool onDarkSurface;

  static const double _startAngle = -math.pi * 11 / 12; // -165 deg
  static const double _totalSweep = math.pi * 5 / 6; // +150 deg

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 16);
    final radius = math.min(size.width * 0.42, size.height - 34).clamp(64.0, 112.0);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    void drawZone(double startFrac, double sweepFrac, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        arcRect,
        _startAngle + _totalSweep * startFrac,
        _totalSweep * sweepFrac,
        false,
        paint,
      );
    }

    drawZone(0.0, 0.35, AppColors.normalEmerald);
    drawZone(0.35, 0.15, AppColors.warningAmber);
    drawZone(0.50, 0.50, AppColors.alertRed);

    // 5 scale ticks & accessible 14 sp labels (0, 25, 50, 75, 100)
    final tickPaint = Paint()
      ..color = onDarkSurface ? AppColors.darkMuted : AppColors.royalNavy
      ..strokeWidth = 1.6;
    final labelColor =
        onDarkSurface ? AppColors.darkMuted : AppColors.royalNavy;

    for (final tickVal in const <int>[0, 25, 50, 75, 100]) {
      final angle = _startAngle + _totalSweep * (tickVal / 100.0);
      final p1 = Offset(
        center.dx + (radius + 9) * math.cos(angle),
        center.dy + (radius + 9) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius + 15) * math.cos(angle),
        center.dy + (radius + 15) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '$tickVal',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelPos = Offset(
        center.dx + (radius + 26) * math.cos(angle) - tp.width / 2,
        center.dy + (radius + 24) * math.sin(angle) - tp.height / 2,
      );
      tp.paint(canvas, labelPos);
    }

    // Tapered Royal Navy needle with bright Vibrant Azure center pivot
    final needleAngle = _startAngle + _totalSweep * (score / 100.0);
    final tip = Offset(
      center.dx + (radius - 6) * math.cos(needleAngle),
      center.dy + (radius - 6) * math.sin(needleAngle),
    );
    final perpAngle = needleAngle + math.pi / 2;
    const baseHalf = 4.5;
    final baseLeft = Offset(
      center.dx + baseHalf * math.cos(perpAngle),
      center.dy + baseHalf * math.sin(perpAngle),
    );
    final baseRight = Offset(
      center.dx - baseHalf * math.cos(perpAngle),
      center.dy - baseHalf * math.sin(perpAngle),
    );

    final needlePath = Path()
      ..moveTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    canvas.drawPath(
      needlePath,
      Paint()
        ..color = onDarkSurface ? AppColors.pureWhite : AppColors.royalNavy
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      8.0,
      Paint()..color = onDarkSurface ? AppColors.pureWhite : AppColors.royalNavy,
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = AppColors.vibrantAzure,
    );
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.onDarkSurface != onDarkSurface;
  }
}
