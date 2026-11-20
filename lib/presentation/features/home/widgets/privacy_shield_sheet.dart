import 'package:material_ui/material_ui.dart';

import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/onboarding_status.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';

/// Opens the S-03 Privacy & Clinical Safety summary sheet triggered from the
/// top-right shield button.
Future<void> showPrivacyShieldSheet(
  BuildContext context, {
  required OnboardingStatus status,
  required VoidCallback onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PrivacyShieldSheet(
      status: status,
      onOpenSettings: () {
        Navigator.of(sheetContext).pop();
        onOpenSettings();
      },
    ),
  );
}

class PrivacyShieldSheet extends StatelessWidget {
  const PrivacyShieldSheet({
    super.key,
    required this.status,
    required this.onOpenSettings,
  });

  final OnboardingStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final consent = status.consent;
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
                    child: ParkinIcons.offlineShield(
                      color: AppColors.clinicalAzure,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ClinicalCopy.privacyShieldTitle,
                      style: AppTypography.screenTitle(size: 20),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Tutup panel privasi',
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Material(
                        color: AppColors.iceSurface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          key: const Key('shield_close_button'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pop(),
                          child: Center(
                            child: ParkinIcons.close(
                              color: AppColors.royalNavy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ClinicalCopy.privacyShieldGuarantee,
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 14),
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
                    Text(
                      'Status Izin UU PDP Anda',
                      style: AppTypography.cardTitle(size: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mode Akses: ${status.authMode?.labelId ?? '-'}',
                      style: AppTypography.captionBadge(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kamera Lokal: ${consent.consentLocal ? 'Aktif' : 'Nonaktif'}',
                      style: AppTypography.captionBadge(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sinkronisasi Dokter: ${consent.consentSkeletonSync ? 'Aktif' : 'Nonaktif'}',
                      style: AppTypography.captionBadge(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audit Video Cadangan: ${consent.consentCloudVideo ? 'Aktif' : 'Nonaktif'}',
                      style: AppTypography.captionBadge(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberSoftBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.amberSoftBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ParkinIcons.alertTriangle(
                        color: AppColors.warningAmberText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Alat bantu skrining FoG, bukan diagnosis medis resmi. Hubungi layanan gawat darurat jika pasien terjatuh atau cedera.',
                        style: AppTypography.captionBadge(
                          color: AppColors.amberDarkText,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ParkinSecondaryIceButton(
                key: const Key('shield_open_settings_button'),
                title: 'Buka Pengaturan Privasi',
                subtitle: 'Lihat profil dan atur ulang persetujuan UU PDP',
                leadingIcon: ParkinIcons.navSettings(
                  color: AppColors.onIceAzure,
                ),
                onPressed: onOpenSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
