import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';
import 'parkin_primary_pill_button.dart';

/// R-27 Loading State card (`State/LoadingDSP`) reassuring patients while
/// post-session analysis & temporary video deletion complete.
class ParkinLoadingDspCard extends StatelessWidget {
  const ParkinLoadingDspCard({
    super.key,
    required this.title,
    required this.description,
    this.progress,
    this.progressLabel,
  });

  final String title;
  final String description;
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final pct = progress != null ? (progress!.clamp(0.0, 1.0) * 100).round() : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4.5,
                color: AppColors.clinicalAzure,
                backgroundColor: AppColors.iceSurface,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle(size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge(size: 14.5),
          ),
          if (progress != null || progressLabel != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppColors.clinicalAzure,
                backgroundColor: AppColors.iceSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (pct != null) '$pct%',
                if (progressLabel != null && progressLabel!.isNotEmpty)
                  progressLabel!,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: AppTypography.captionBadge(
                color: AppColors.onIceAzure,
                weight: FontWeight.w700,
                tabular: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// R-27 Error State card (`State/ErrorLowLight`) explaining poor leg keypoint
/// visibility and providing a >= 64 dp recovery CTA button.
class ParkinErrorLowLightCard extends StatelessWidget {
  const ParkinErrorLowLightCard({
    super.key,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.onRetry,
    this.retryKey,
  });

  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.amberSoftBorder, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.amberSoftBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: ParkinIcons.alertTriangle(
                    color: AppColors.warningAmberText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.cardTitle(
                      color: AppColors.amberDarkText,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: AppTypography.bodyLarge(size: 14.5),
            ),
            const SizedBox(height: 16),
            ParkinPrimaryPillButton(
              key: retryKey,
              label: ctaLabel,
              leadingIcon: ParkinIcons.cameraLegs(
                color: AppColors.clinicalAzure,
              ),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
