import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Granular UU PDP opt-in card with tremor-resilient full-row touch target
/// and 56x32 high-contrast tactile pill switch aligned with Figma S-02.
class ParkinConsentToggleCard extends StatelessWidget {
  const ParkinConsentToggleCard({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.isMandatory,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool isMandatory;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final badgeBg =
        isMandatory ? AppColors.iceSurface : AppColors.subtleBorderLight;
    final badgeFg =
        isMandatory ? AppColors.onIceAzure : AppColors.mutedSlate;

    return Semantics(
      toggled: value,
      label: '$title (${isMandatory ? 'Wajib' : 'Opsional'}). $description',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? AppColors.clinicalAzure : AppColors.subtleBorderLight,
            width: value ? 1.5 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              title,
                              style: AppTypography.cardTitle(
                                color: AppColors.royalNavy,
                                size: 15.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isMandatory ? 'Wajib' : 'Opsional',
                                style: AppTypography.captionBadge(
                                  color: badgeFg,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: AppTypography.captionBadge(
                            color: AppColors.mutedSlate,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TactileSwitchPill(value: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TactileSwitchPill extends StatelessWidget {
  const _TactileSwitchPill({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 54,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.clinicalAzure : AppColors.darkMuted,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.pureWhite,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
