import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';

/// Stacked >= 64 dp accessible checklist & menu tile aligned with Figma S-04
/// (`ParkinStackedMenuTile`), pairing high-contrast Azure/Ice surfaces with
/// distinct contextual leading icons and a clear checkmark indicator.
class ParkinStackedMenuTile extends StatelessWidget {
  const ParkinStackedMenuTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.isChecked,
    required this.onPressed,
    this.semanticLabel,
  });

  final String title;
  final String subtitle;
  final Widget leadingIcon;
  final bool isChecked;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final azureShadow =
        themeExt?.azureCtaShadow ?? ParkinThemeExt.standard.azureCtaShadow;

    final bgColor = isChecked ? AppColors.clinicalAzure : AppColors.iceSurface;
    final titleColor = isChecked ? AppColors.pureWhite : AppColors.royalNavy;
    final subtitleColor = isChecked ? AppColors.pureWhite : AppColors.mutedSlate;

    return Semantics(
      button: true,
      checked: isChecked,
      label: semanticLabel ?? '$title. $subtitle',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: isChecked
                ? null
                : Border.all(color: AppColors.skyCard, width: 1.5),
            boxShadow: isChecked ? azureShadow : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.pureWhite,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: leadingIcon,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.cardTitle(
                              color: titleColor,
                              size: 16.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.captionBadge(
                              color: subtitleColor,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        shape: BoxShape.circle,
                        border: isChecked
                            ? null
                            : Border.all(color: AppColors.skyCard, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: isChecked
                          ? ParkinIcons.check(
                              color: AppColors.clinicalAzure,
                              size: 18,
                            )
                          : const SizedBox.shrink(),
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
