import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_consent_toggle_card.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';

/// S-02: Granular UU PDP No. 27/2022 Informed Consent & Verbatim Medical Disclaimer.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(onboardingControllerProvider.notifier)
        .submitConsent();
    if (ok && context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final draft = state.draftConsent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.slateCanvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: 'Kembali ke halaman masuk',
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: 56,
                            ),
                            child: TextButton(
                              key: const Key('consent_back_button'),
                              onPressed: () => context.go('/welcome'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.royalNavy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                '< Kembali',
                                style: AppTypography.buttonLabel(
                                  color: AppColors.royalNavy,
                                  size: 15.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ClinicalCopy.consentScreenTitle,
                        style: AppTypography.screenTitle(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ClinicalCopy.consentScreenSubtitle,
                        style: AppTypography.bodyLarge(size: 14.5),
                      ),
                      const SizedBox(height: 16),
                      _MedicalDisclaimerBox(),
                      const SizedBox(height: 16),
                      Text(
                        'Pilih izin pemrosesan data:',
                        style: AppTypography.cardTitle(size: 15.5),
                      ),
                      const SizedBox(height: 12),
                      ParkinConsentToggleCard(
                        key: const Key('consent_local_card'),
                        title: ClinicalCopy.consentLocalTitle,
                        description: ClinicalCopy.consentLocalDesc,
                        value: draft.consentLocal,
                        isMandatory: true,
                        onChanged: notifier.setConsentLocal,
                      ),
                      const SizedBox(height: 12),
                      ParkinConsentToggleCard(
                        key: const Key('consent_sync_card'),
                        title: ClinicalCopy.consentSyncTitle,
                        description: ClinicalCopy.consentSyncDesc,
                        value: draft.consentSkeletonSync,
                        isMandatory: false,
                        onChanged: notifier.setConsentSkeletonSync,
                      ),
                      const SizedBox(height: 12),
                      ParkinConsentToggleCard(
                        key: const Key('consent_audit_card'),
                        title: ClinicalCopy.consentAuditTitle,
                        description: ClinicalCopy.consentAuditDesc,
                        value: draft.consentCloudVideo,
                        isMandatory: false,
                        onChanged: notifier.setConsentCloudVideo,
                      ),
                      if (!draft.canProceed) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.redSoftBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.alertRed),
                            ),
                            child: Row(
                              children: [
                                ParkinIcons.alertTriangle(
                                  color: AppColors.redDarkText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Izin kamera lokal wajib diaktifkan agar deteksi FoG dapat berjalan.',
                                    style: AppTypography.captionBadge(
                                      color: AppColors.redDarkText,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            state.errorMessage!,
                            style: AppTypography.captionBadge(
                              color: AppColors.redDarkText,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.slateCanvas,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalNavy.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: ParkinPrimaryPillButton(
                    key: const Key('consent_submit_button'),
                    label: 'Setuju & Lanjutkan',
                    leadingIcon: ParkinIcons.check(
                      color: draft.canProceed
                          ? AppColors.clinicalAzure
                          : AppColors.mutedSlate,
                    ),
                    isLoading: state.isSubmitting,
                    onPressed: draft.canProceed
                        ? () => _submit(context, ref)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicalDisclaimerBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amberSoftBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ParkinIcons.alertTriangle(color: AppColors.warningAmberText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PERHATIAN MEDIS',
                  style: AppTypography.captionBadge(
                    color: AppColors.amberDarkText,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ClinicalCopy.medicalDisclaimer,
            style: AppTypography.captionBadge(
              color: AppColors.amberDarkText,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
