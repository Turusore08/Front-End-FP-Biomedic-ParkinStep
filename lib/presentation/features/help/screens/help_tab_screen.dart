import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';

/// Tab 2 (`/help`): Accessible camera framing guide, audio guide trigger, and medical disclaimer.
class HelpTabScreen extends ConsumerWidget {
  const HelpTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(
      onboardingControllerProvider.select((s) => s.isSpeakingGuide),
    );

    return Scaffold(
      backgroundColor: AppColors.slateCanvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Panduan Penggunaan',
                style: AppTypography.screenTitle(size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Langkah praktis menyiapkan ruangan dan kamera ponsel agar deteksi FoG berjalan akurat dan aman.',
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 16),
              ParkinSecondaryIceButton(
                key: const Key('help_voice_button'),
                title: isSpeaking
                    ? 'Hentikan Panduan Suara'
                    : 'Dengarkan Panduan Lengkap',
                subtitle: 'Audio bahasa Indonesia yang jelas untuk pasien',
                leadingIcon: ParkinIcons.soundWave(color: AppColors.onIceAzure),
                onPressed: () => ref
                    .read(onboardingControllerProvider.notifier)
                    .toggleVoiceGuide(ClinicalCopy.helpVoiceGuideDetail),
              ),
              const SizedBox(height: 18),
              const _GuideCard(
                title: '1. Jarak & Posisi Kamera (2-3 meter)',
                body:
                    'Sandarkan ponsel setinggi pinggang dengan jarak 2 hingga 3 meter sehingga pinggul sampai mata kaki terlihat penuh di layar.',
              ),
              const SizedBox(height: 10),
              const _GuideCard(
                title: '2. Pencahayaan & Lantai Aman',
                body:
                    'Pastikan lampu ruangan terang, lantai kering, bebas kabel, dan sediakan kursi kokoh atau pendamping di sekitar Anda.',
              ),
              const SizedBox(height: 10),
              const _GuideCard(
                title: '3. Pilih Tes & Rekam Sesuai Aba-Aba',
                body:
                    'Pilih Tes Berputar 360°, Berjalan Bolak-Balik, atau Duduk-Berdiri, catat status obat ON/OFF, lalu ikuti perintah suara dan teks selama 2 menit sebelum menekan Kirim.',
              ),
              const SizedBox(height: 10),
              const _GuideCard(
                title: '4. Video Skeleton Privat di HP Anda',
                body:
                    'Setelah Anda menekan Kirim, Pose Extractor memetakan skeleton langsung di HP. Video beserta garis skeleton dapat diputar ulang, diekspor ke MP4, atau dihapus manual kapan saja.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.amberSoftBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.amberSoftBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ParkinIcons.alertTriangle(
                          color: AppColors.warningAmberText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Perhatian Medis',
                            style: AppTypography.cardTitle(
                              color: AppColors.amberDarkText,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ClinicalCopy.medicalDisclaimer,
                      style: AppTypography.bodyLarge(
                        color: AppColors.amberDarkText,
                        size: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.cardTitle(size: 16.5),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.bodyLarge(size: 14.5),
          ),
        ],
      ),
    );
  }
}
