import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_brand_lockup.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../widgets/login_bottom_sheet.dart';
import '../widgets/onboarding_help_dialog.dart';

/// S-01: Welcome, Account Sign-In & Offline-First Local Entry
/// Direct implementation of Figma v2 S-01 and `contoh/16.10.35.jpeg`.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleContinueOffline(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await ref
        .read(onboardingControllerProvider.notifier)
        .continueOffline();
    if (ok && context.mounted) {
      context.go('/consent');
    }
  }

  void _openLoginSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoginBottomSheet(
        onSuccess: () {
          if (context.mounted) {
            context.go('/consent');
          }
        },
      ),
    );
  }

  void _openHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const OnboardingHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 32).clamp(0.0, 4000.0),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: ParkinBrandLockup(
                                variant: ParkinLockupVariant.dark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _HeaderHelpButton(
                              onPressed: () => _openHelpDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          ClinicalCopy.welcomeTitle,
                          style: AppTypography.screenTitle(
                            color: AppColors.pureWhite,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ClinicalCopy.welcomeSubtitle,
                          style: AppTypography.bodyLarge(
                            color: AppColors.darkMuted,
                          ),
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 16),
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
                                      state.errorMessage!,
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
                        const SizedBox(height: 24),
                        const Expanded(child: SizedBox.shrink()),
                        ParkinPrimaryPillButton(
                          key: const Key('welcome_login_button'),
                          label: 'Masuk dengan Akun',
                          leadingIcon: ParkinIcons.login(),
                          onPressed: state.isSubmitting
                              ? null
                              : () => _openLoginSheet(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ClinicalCopy.welcomePrivacyNote,
                          textAlign: TextAlign.center,
                          style: AppTypography.captionBadge(
                            color: AppColors.darkMuted,
                            weight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: AppColors.subtleBorderDark,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ATAU',
                                style: AppTypography.captionBadge(
                                  color: AppColors.darkMuted,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: AppColors.subtleBorderDark,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ParkinSecondaryIceButton(
                          key: const Key('welcome_offline_button'),
                          title: 'Gunakan Mode Offline Lokal',
                          subtitle:
                              'Data tersimpan aman terenkripsi di ponsel ini',
                          leadingIcon: ParkinIcons.offlineShield(),
                          isLoading: state.isSubmitting,
                          onPressed: () => _handleContinueOffline(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderHelpButton extends StatelessWidget {
  const _HeaderHelpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bantuan cara kerja aplikasi',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('welcome_help_button'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: ParkinIcons.help(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
