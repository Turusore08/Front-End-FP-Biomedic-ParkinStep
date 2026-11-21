import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/clinical_session_providers.dart';
import '../../../../di/dashboard_providers.dart';
import '../../../../di/onboarding_providers.dart';
import '../../../../di/session_prep_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/enums/medication_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_stacked_menu_tile.dart';

/// S-04: Pre-Flight Safety Checklist & ON/OFF Levodopa Medication Confirmation.
class PreFlightChecklistScreen extends ConsumerStatefulWidget {
  const PreFlightChecklistScreen({super.key});

  @override
  ConsumerState<PreFlightChecklistScreen> createState() =>
      _PreFlightChecklistScreenState();
}

class _PreFlightChecklistScreenState
    extends ConsumerState<PreFlightChecklistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Load the pose/FoG models while the patient works through the
      // checklist, so "Lanjut ke Kamera" opens the camera without a stall.
      unawaited(
        ref.read(edgeInferencePortProvider).warmUp().catchError((Object _) {}),
      );
      final latestLog =
          ref.read(homeDashboardControllerProvider).summary.latestMedicationLog;
      if (latestLog != null) {
        ref
            .read(preFlightControllerProvider.notifier)
            .seedMedStateIfUnconfirmed(latestLog.medState);
      }
    });
  }

  Future<void> _navigateBack() async {
    await ref.read(onboardingControllerProvider.notifier).stopVoiceGuide();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepState = ref.watch(preFlightControllerProvider);
    final checklist = prepState.checklist;
    final isSpeaking = ref.watch(
      onboardingControllerProvider.select((s) => s.isSpeakingGuide),
    );
    final remainingCount = 4 - checklist.completedCount;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.pureWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: < Kembali & Voice Guide Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Semantics(
                        button: true,
                        label: 'Kembali ke layar sebelumnya',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              key: const Key('preflight_back_button'),
                              onTap: _navigateBack,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ParkinIcons.arrowBack(
                                        color: AppColors.royalNavy,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kembali',
                                        style: AppTypography.buttonLabel(
                                          color: AppColors.royalNavy,
                                          size: 16.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: isSpeaking
                          ? 'Hentikan panduan suara keselamatan'
                          : 'Dengarkan panduan suara keselamatan',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('preflight_voice_button'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => ref
                                .read(onboardingControllerProvider.notifier)
                                .toggleVoiceGuide(
                                  ClinicalCopy.preflightVoiceGuide,
                                ),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSpeaking
                                      ? AppColors.clinicalAzure
                                      : AppColors.iceSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: ParkinIcons.soundWave(
                                  color: isSpeaking
                                      ? AppColors.pureWhite
                                      : AppColors.onIceAzure,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  ClinicalCopy.preflightTitle,
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  ClinicalCopy.preflightSubtitle,
                  style: AppTypography.bodyLarge(size: 14.5),
                ),
                const SizedBox(height: 18),

                ParkinStackedMenuTile(
                  key: const Key('checklist_floor_tile'),
                  title: ClinicalCopy.preflightFloorTitle,
                  subtitle: ClinicalCopy.preflightFloorDesc,
                  leadingIcon: ParkinIcons.floorDry(
                    color: AppColors.clinicalAzure,
                  ),
                  isChecked: checklist.floorSafe,
                  onPressed: () => ref
                      .read(preFlightControllerProvider.notifier)
                      .toggleFloorSafe(),
                ),
                const SizedBox(height: 12),
                ParkinStackedMenuTile(
                  key: const Key('checklist_space_tile'),
                  title: ClinicalCopy.preflightSpaceTitle,
                  subtitle: ClinicalCopy.preflightSpaceDesc,
                  leadingIcon: ParkinIcons.radiusSpace(
                    color: AppColors.clinicalAzure,
                  ),
                  isChecked: checklist.spaceClear,
                  onPressed: () => ref
                      .read(preFlightControllerProvider.notifier)
                      .toggleSpaceClear(),
                ),
                const SizedBox(height: 12),
                ParkinStackedMenuTile(
                  key: const Key('checklist_support_tile'),
                  title: ClinicalCopy.preflightSupportTitle,
                  subtitle: ClinicalCopy.preflightSupportDesc,
                  leadingIcon: ParkinIcons.chairSupport(
                    color: AppColors.clinicalAzure,
                  ),
                  isChecked: checklist.supportReady,
                  onPressed: () => ref
                      .read(preFlightControllerProvider.notifier)
                      .toggleSupportReady(),
                ),
                const SizedBox(height: 12),
                ParkinStackedMenuTile(
                  key: const Key('checklist_attire_tile'),
                  title: ClinicalCopy.preflightAttireTitle,
                  subtitle: ClinicalCopy.preflightAttireDesc,
                  leadingIcon: ParkinIcons.cameraLegs(
                    color: AppColors.clinicalAzure,
                  ),
                  isChecked: checklist.attireAndFraming,
                  onPressed: () => ref
                      .read(preFlightControllerProvider.notifier)
                      .toggleAttireAndFraming(),
                ),

                const SizedBox(height: 22),
                Text(
                  'Status Obat Levodopa Saat Ini',
                  style: AppTypography.cardTitle(size: 16.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MedChipButton(
                      key: const Key('preflight_med_on'),
                      state: MedicationState.on,
                      selected: checklist.medState == MedicationState.on,
                      onPressed: () => ref
                          .read(preFlightControllerProvider.notifier)
                          .selectMedState(MedicationState.on),
                    ),
                    const SizedBox(width: 8),
                    _MedChipButton(
                      key: const Key('preflight_med_off'),
                      state: MedicationState.off,
                      selected: checklist.medState == MedicationState.off,
                      onPressed: () => ref
                          .read(preFlightControllerProvider.notifier)
                          .selectMedState(MedicationState.off),
                    ),
                    const SizedBox(width: 8),
                    _MedChipButton(
                      key: const Key('preflight_med_unknown'),
                      state: MedicationState.unknown,
                      selected: checklist.medState == MedicationState.unknown,
                      onPressed: () => ref
                          .read(preFlightControllerProvider.notifier)
                          .selectMedState(MedicationState.unknown),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: checklist.isAllChecked
                        ? AppColors.emeraldSoftBg
                        : AppColors.iceSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: checklist.isAllChecked
                          ? AppColors.normalEmerald
                          : AppColors.skyCard,
                    ),
                  ),
                  child: Row(
                    children: [
                      checklist.isAllChecked
                          ? ParkinIcons.check(
                              color: AppColors.emeraldDarkText,
                              size: 20,
                            )
                          : ParkinIcons.offlineShield(
                              color: AppColors.onIceAzure,
                              size: 20,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          checklist.isAllChecked
                              ? 'Seluruh 4 syarat keselamatan siap. Anda dapat melanjutkan.'
                              : 'Centang $remainingCount syarat lagi untuk melanjutkan ke kamera.',
                          style: AppTypography.captionBadge(
                            color: checklist.isAllChecked
                                ? AppColors.emeraldDarkText
                                : AppColors.onIceAzure,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                ParkinPrimaryPillButton(
                  key: const Key('preflight_continue_button'),
                  label: 'Lanjut ke Kamera (${checklist.completedCount}/4)',
                  leadingIcon: ParkinIcons.cameraLegs(
                    color: checklist.isAllChecked
                        ? AppColors.clinicalAzure
                        : AppColors.mutedSlate,
                  ),
                  onPressed: checklist.isAllChecked
                      ? () {
                          final ok = ref
                              .read(preFlightControllerProvider.notifier)
                              .confirmReady();
                          if (ok && context.mounted) {
                            context.push('/session-live');
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedChipButton extends StatelessWidget {
  const _MedChipButton({
    super.key,
    required this.state,
    required this.selected,
    required this.onPressed,
  });

  final MedicationState state;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.clinicalAzure : AppColors.iceSurface;
    final fgColor = selected ? AppColors.pureWhite : AppColors.royalNavy;
    final borderColor = selected ? AppColors.clinicalAzure : AppColors.skyCard;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '${state.labelId}: ${state.descriptionId}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Material(
            color: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.labelId,
                      style: AppTypography.buttonLabel(
                        color: fgColor,
                        size: 14.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
