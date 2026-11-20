import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';

/// Soft-ice gradient metric summary banner (>= 84 dp) displaying either the latest
/// tabular FoG metric or an honest pre-screening status summary.
class ParkinMetricPill extends StatelessWidget {
  const ParkinMetricPill({
    super.key,
    required this.heroText,
    required this.subtitleText,
    this.badgeLabel,
    this.onTap,
  });

  final String heroText;
  final String subtitleText;
  final String? badgeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: badgeLabel != null
          ? '$heroText. $subtitleText. $badgeLabel'
          : '$heroText. $subtitleText',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEBF8FE),
                AppColors.softIce,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.skyCard),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.pureWhite,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: ParkinIcons.strideShoe(
                        color: AppColors.clinicalAzure,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    heroText,
                                    style: AppTypography.heroMetric(size: 24),
                                  ),
                                ),
                              ),
                              if (badgeLabel != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.pureWhite,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.skyCard),
                                  ),
                                  child: Text(
                                    badgeLabel!,
                                    style: AppTypography.captionBadge(
                                      color: AppColors.onIceAzure,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: AppTypography.captionBadge(
                              color: AppColors.mutedSlate,
                              weight: FontWeight.w500,
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
