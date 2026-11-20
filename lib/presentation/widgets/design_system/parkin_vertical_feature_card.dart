import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Vertical Clinical Azure action card with a tilted white squircle illustration tile,
/// aligned with Figma S-03 (`ParkinVerticalFeatureCard`) & accessible motor ergonomics.
class ParkinVerticalFeatureCard extends StatelessWidget {
  const ParkinVerticalFeatureCard({
    super.key,
    required this.title,
    required this.illustration,
    required this.tiltRadians,
    required this.onPressed,
    this.semanticLabel,
  });

  final String title;
  final Widget illustration;
  final double tiltRadians;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final shadow =
        themeExt?.azureCtaShadow ?? ParkinThemeExt.standard.azureCtaShadow;

    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 158),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.clinicalAzure,
            borderRadius: BorderRadius.circular(20),
            boxShadow: shadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Transform.rotate(
                      angle: tiltRadians,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: illustration,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.buttonLabel(
                        color: AppColors.pureWhite,
                        size: 15.0,
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
