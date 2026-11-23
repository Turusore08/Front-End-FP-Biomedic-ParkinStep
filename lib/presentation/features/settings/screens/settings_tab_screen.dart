import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/clinical_session_providers.dart';
import '../../../../di/onboarding_providers.dart';
import '../../../../di/video_playback_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_brand_lockup.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';

/// Tab 3 (`/settings`): Patient profile, active UU PDP consent flags, and onboarding reset.
class SettingsTabScreen extends ConsumerStatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  ConsumerState<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends ConsumerState<SettingsTabScreen> {
  bool _isDeletingVideos = false;
  bool _videosDeleted = false;

  Future<void> _handleDeleteAllVideos() async {
    if (_isDeletingVideos) return;
    setState(() => _isDeletingVideos = true);
    try {
      await ref.read(recordedMediaPortProvider).deleteAllSessionMedia();
      await ref
          .read(clinicalSessionControllerProvider.notifier)
          .deleteCompletedSessionVideo();
      if (!mounted) return;
      setState(() {
        _isDeletingVideos = false;
        _videosDeleted = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingVideos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(onboardingControllerProvider).status;
    final consent = status.consent;

    return Scaffold(
      backgroundColor: AppColors.slateCanvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  ParkinBrandLockup(variant: ParkinLockupVariant.light),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Pengaturan & Privasi',
                style: AppTypography.screenTitle(size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Kelola preferensi penyimpanan lokal dan persetujuan UU PDP No. 27/2022 Anda.',
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.subtleBorderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil & Izin Tersimpan',
                      style: AppTypography.cardTitle(size: 17),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pengguna: ${status.displayName}',
                      style: AppTypography.captionBadge(
                        color: AppColors.royalNavy,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
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
              const SizedBox(height: 18),
              if (_videosDeleted) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('settings_videos_deleted_banner'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoftBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.normalEmerald),
                    ),
                    child: Text(
                      'Semua video rekaman & data skeleton lokal telah dihapus permanen dari perangkat.',
                      style: AppTypography.captionBadge(
                        color: AppColors.emeraldDarkText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ParkinSecondaryIceButton(
                key: const Key('settings_delete_all_videos_button'),
                title: 'Hapus Semua Video Rekaman',
                subtitle: 'Hapus permanen semua file MP4 & skeleton lokal',
                leadingIcon: ParkinIcons.stopSquare(color: AppColors.alertRed),
                isLoading: _isDeletingVideos,
                onPressed: _isDeletingVideos
                    ? null
                    : () => _handleDeleteAllVideos(),
              ),
              const SizedBox(height: 12),
              ParkinSecondaryIceButton(
                key: const Key('settings_reset_onboarding_button'),
                title: 'Ubah Izin Privasi & Ulangi Onboarding',
                subtitle: 'Kembali ke layar selamat datang S-01',
                leadingIcon: ParkinIcons.offlineShield(
                  color: AppColors.onIceAzure,
                ),
                onPressed: () async {
                  await ref
                      .read(onboardingControllerProvider.notifier)
                      .resetOnboarding();
                  if (context.mounted) {
                    context.go('/welcome');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
