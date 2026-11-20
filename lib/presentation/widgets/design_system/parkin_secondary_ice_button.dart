import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Soft-ice secondary action pill (64 dp min height) with white left circular
/// icon badge and high-contrast On-Ice Azure (#006299 -> 5.58:1) + Muted Slate subtitle.
class ParkinSecondaryIceButton extends StatelessWidget {
  const ParkinSecondaryIceButton({
    super.key,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String title;
  final String? subtitle;
  final Widget leadingIcon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: subtitle != null ? '$title. $subtitle' : title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.softIce,
            borderRadius: BorderRadius.circular(18),
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
                      child: leadingIcon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTypography.buttonLabel(
                              color: AppColors.onIceAzure,
                              size: 16.0,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: AppTypography.captionBadge(
                                color: AppColors.mutedSlate,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
