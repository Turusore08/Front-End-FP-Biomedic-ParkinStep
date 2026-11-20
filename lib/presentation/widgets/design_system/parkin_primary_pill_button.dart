import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Beats-Medical-inspired primary pill CTA adapted for Parkinson's motor ergonomics:
/// minimum 64 dp height, crisp 46 dp white icon badge on the left, high-contrast
/// Clinical Azure (#0077B6 -> 4.87:1 with #FFFFFF), and selective Azure elevation.
class ParkinPrimaryPillButton extends StatelessWidget {
  const ParkinPrimaryPillButton({
    super.key,
    required this.label,
    required this.leadingIcon,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor = AppColors.clinicalAzure,
    this.semanticLabel,
  });

  final String label;
  final Widget leadingIcon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final effectiveBg = enabled ? backgroundColor : AppColors.subtleBorderLight;
    final effectiveFg = enabled ? AppColors.pureWhite : AppColors.mutedSlate;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? (themeExt?.azureCtaShadow ?? ParkinThemeExt.standard.azureCtaShadow)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.clinicalAzure,
                              ),
                            )
                          : leadingIcon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isLoading ? 'Memproses...' : label,
                        textAlign: TextAlign.center,
                        style: AppTypography.buttonLabel(color: effectiveFg),
                      ),
                    ),
                    const SizedBox(width: 18),
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
