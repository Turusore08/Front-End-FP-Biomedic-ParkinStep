import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';

/// Elderly-friendly onboarding help modal triggered by the `?` button on S-01.
class OnboardingHelpDialog extends ConsumerWidget {
  const OnboardingHelpDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(
      onboardingControllerProvider.select((s) => s.isSpeakingGuide),
    );
    final notifier = ref.read(onboardingControllerProvider.notifier);

    return Dialog(
      backgroundColor: AppColors.pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.iceSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: ParkinIcons.help(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ClinicalCopy.helpDialogTitle,
                    style: AppTypography.cardTitle(size: 19),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _HelpPoint(
              number: '1',
              title: 'Cukup Kamera HP Biasa',
              body:
                  'Tidak memerlukan alat sensor tambahan di kaki. Aplikasi membaca pola gerak sendi dari video jarak 2 sampai 3 meter.',
            ),
            const SizedBox(height: 12),
            const _HelpPoint(
              number: '2',
              title: 'Video Diproses Lokal & Dihapus',
              body:
                  'Video tidak pernah disimpan ke galeri atau diunggah tanpa izin Anda.',
            ),
            const SizedBox(height: 12),
            const _HelpPoint(
              number: '3',
              title: 'Bisa Dipakai Offline Sepenuhnya',
              body:
                  'Pilih Mode Offline Lokal jika sedang berada di rumah atau puskesmas tanpa sinyal internet stabil.',
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: OutlinedButton(
                onPressed: () =>
                    notifier.toggleVoiceGuide(ClinicalCopy.helpVoiceSummary),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.royalNavy,
                  side: const BorderSide(
                    color: AppColors.clinicalAzure,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  isSpeaking
                      ? 'Hentikan Panduan Suara'
                      : 'Dengarkan Penjelasan Suara',
                  textAlign: TextAlign.center,
                  style: AppTypography.buttonLabel(
                    color: AppColors.royalNavy,
                    size: 15.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ParkinPrimaryPillButton(
              label: 'Mengerti',
              leadingIcon: ParkinIcons.check(),
              onPressed: () {
                notifier.stopVoiceGuide();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpPoint extends StatelessWidget {
  const _HelpPoint({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.softIce,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: AppTypography.captionBadge(
              color: AppColors.royalNavy,
              weight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cardTitle(size: 15.5),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTypography.captionBadge(
                  color: AppColors.mutedSlate,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
