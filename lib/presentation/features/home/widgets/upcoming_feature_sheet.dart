import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import 'medication_log_sheet.dart';

enum ParkinUpcomingFlow { tes360, cueingRas }

/// Honest interactive preview modal for Tes 360 (S-04..S-06) and Cueing RAS (S-07)
/// ensuring zero dead controls while those camera/audio stages are implemented next.
Future<void> showUpcomingFeatureSheet(
  BuildContext context, {
  required ParkinUpcomingFlow flow,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => UpcomingFeatureSheet(
      flow: flow,
      onOpenMedicationSheet: () {
        Navigator.of(sheetContext).pop();
        showMedicationLogSheet(context);
      },
    ),
  );
}

class UpcomingFeatureSheet extends StatelessWidget {
  const UpcomingFeatureSheet({
    super.key,
    required this.flow,
    required this.onOpenMedicationSheet,
  });

  final ParkinUpcomingFlow flow;
  final VoidCallback onOpenMedicationSheet;

  @override
  Widget build(BuildContext context) {
    final isTes = flow == ParkinUpcomingFlow.tes360;
    final title = isTes ? 'Persiapan Tes 360°' : 'Cueing RAS Mandiri';
    final badgeText = isTes
        ? 'Tahap Berikutnya: S-04 Checklist & S-05 Kamera'
        : 'Tahap Berikutnya: S-07 Metronom Pulse';
    final description = isTes
        ? 'Modul skrining kamera 360° selama 2 menit sedang disiapkan pada tahap pengembangan berikutnya. Sebelum mulai nanti, pastikan 4 hal ini terpenuhi:'
        : 'Modul metronom ritmis mandiri dengan tombol diamond 64 dp dan umpan balik suara sedang disiapkan pada tahap berikutnya.';
    final points = isTes
        ? const <String>[
            '1. Lantai kering, rata, dan bebas kabel.',
            '2. Ruang berputar bebas halangan minimal 1,5 meter.',
            '3. Kursi kokoh atau pendamping siap di dekat Anda.',
            '4. Pencahayaan ruangan terang agar kaki terlihat jelas.',
          ]
        : const <String>[
            '1. Atur tempo nyaman antara 40 hingga 120 BPM.',
            '2. Gunakan tombol diamond besar tanpa geseran tipis.',
            '3. Ikuti ketukan suara dengan mengangkat lutut stabil.',
          ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.subtleBorderLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                    child: isTes
                        ? ParkinIcons.tes360Illustration(size: 30)
                        : ParkinIcons.cueingRasIllustration(size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.screenTitle(size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.skyCard),
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.captionBadge(
                    color: AppColors.onIceAzure,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.slateCanvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.subtleBorderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < points.length; i++) ...[
                      Text(
                        points[i],
                        style: AppTypography.captionBadge(
                          color: AppColors.royalNavy,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (i != points.length - 1) const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ParkinSecondaryIceButton(
                key: const Key('upcoming_log_med_button'),
                title: 'Catat Obat Sekarang',
                subtitle: 'Simpan status ON / OFF Levodopa terlebih dahulu',
                leadingIcon: ParkinIcons.capsule(
                  color: AppColors.onIceAzure,
                ),
                onPressed: onOpenMedicationSheet,
              ),
              const SizedBox(height: 12),
              ParkinPrimaryPillButton(
                key: const Key('upcoming_close_button'),
                label: 'Tutup',
                leadingIcon: ParkinIcons.check(color: AppColors.clinicalAzure),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
