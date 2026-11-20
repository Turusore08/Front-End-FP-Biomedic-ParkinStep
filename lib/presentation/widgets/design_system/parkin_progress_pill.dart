import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Capsule progress pill (`#1AEAD8` fill inside crisp pill border) paired with
/// tabular MM:SS elapsed time indicator for S-06 live gait session HUD.
class ParkinProgressPill extends StatelessWidget {
  const ParkinProgressPill({
    super.key,
    required this.elapsedSeconds,
    required this.totalSeconds,
    this.onDarkSurface = false,
  });

  final int elapsedSeconds;
  final int totalSeconds;
  final bool onDarkSurface;

  static String formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final total = totalSeconds <= 0 ? 120 : totalSeconds;
    final progress = (elapsedSeconds / total).clamp(0.0, 1.0);
    final labelColor = onDarkSurface ? AppColors.pureWhite : AppColors.royalNavy;
    final borderColor =
        onDarkSurface ? AppColors.darkMuted : AppColors.royalNavy;
    final trackColor =
        onDarkSurface ? AppColors.midnightNavy : AppColors.pureWhite;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Progres Tes',
                style: AppTypography.captionBadge(
                  color: labelColor,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatDuration(elapsedSeconds)} / ${formatDuration(total)}',
              style: AppTypography.captionBadge(
                color: labelColor,
                weight: FontWeight.w700,
                tabular: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress < 0.04 && elapsedSeconds == 0
                    ? 0.02
                    : progress.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.rhythmAqua,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
