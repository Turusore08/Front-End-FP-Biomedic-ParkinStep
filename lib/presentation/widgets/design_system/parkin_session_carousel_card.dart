import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

enum ParkinSessionCardTone { mint, sky, azure }

/// Recent session summary card (`Mint`, `Sky`, `Azure`) featuring a peeking
/// circular progress ring along its clipped bottom edge, faithful to Figma S-03.
class ParkinSessionCarouselCard extends StatelessWidget {
  const ParkinSessionCarouselCard({
    super.key,
    required this.dateLabel,
    required this.medBadge,
    required this.fogPercentLabel,
    required this.progressFraction,
    required this.tone,
    this.onTap,
  });

  final String dateLabel;
  final String medBadge;
  final String fogPercentLabel;
  final double progressFraction;
  final ParkinSessionCardTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor, trackColor, arcColor) = switch (tone) {
      ParkinSessionCardTone.mint => (
          AppColors.rhythmAqua,
          AppColors.royalNavy,
          AppColors.pureWhite,
          AppColors.royalNavy,
        ),
      ParkinSessionCardTone.sky => (
          AppColors.skyCard,
          AppColors.royalNavy,
          AppColors.pureWhite,
          AppColors.clinicalAzure,
        ),
      ParkinSessionCardTone.azure => (
          AppColors.clinicalAzure,
          AppColors.pureWhite,
          const Color(0x4DFFFFFF),
          AppColors.rhythmAqua,
        ),
    };

    return Semantics(
      button: onTap != null,
      label: 'Sesi $dateLabel, $medBadge, $fogPercentLabel FoG',
      child: SizedBox(
        width: 124,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 142),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: bgColor,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  children: [
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: -30,
                      height: 62,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PeekingRingPainter(
                            progress: progressFraction.clamp(0.08, 1.0),
                            trackColor: trackColor,
                            arcColor: arcColor,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dateLabel,
                              style: AppTypography.captionBadge(
                                color: fgColor,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              fogPercentLabel,
                              style: AppTypography.heroMetric(
                                color: fgColor,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              medBadge,
                              style: AppTypography.captionBadge(
                                color: fgColor,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeekingRingPainter extends CustomPainter {
  const _PeekingRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height * 2) - 8) / 2;
    final center = Offset(size.width / 2, radius + 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PeekingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.arcColor != arcColor;
  }
}
