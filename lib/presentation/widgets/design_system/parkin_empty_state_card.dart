import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';
import 'parkin_primary_pill_button.dart';

/// R-27 Empty State card ('State/EmptyHistory') explaining why no screening
/// history is recorded yet and providing an accessible direct CTA button.
class ParkinEmptyStateCard extends StatelessWidget {
  const ParkinEmptyStateCard({
    super.key,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.onCtaPressed,
    this.ctaKey,
  });

  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback onCtaPressed;
  final Key? ctaKey;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final shadow =
        themeExt?.subtleCardShadow ?? ParkinThemeExt.standard.subtleCardShadow;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.subtleBorderLight),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.iceSurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ParkinIcons.strideShoe(
                  color: AppColors.clinicalAzure,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.cardTitle(size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTypography.bodyLarge(size: 14.5),
          ),
          const SizedBox(height: 18),
          ParkinPrimaryPillButton(
            key: ctaKey,
            label: ctaLabel,
            leadingIcon: ParkinIcons.strideShoe(
              color: AppColors.clinicalAzure,
              size: 24,
            ),
            onPressed: onCtaPressed,
          ),
        ],
      ),
    );
  }
}
