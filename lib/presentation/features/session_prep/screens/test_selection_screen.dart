import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../../di/session_prep_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/enums/session_protocol.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';

/// Picker screen letting Parkinson's patients choose 1 of the 3 2-minute
/// video-recorded screening protocols before the safety checklist & camera.
class TestSelectionScreen extends ConsumerWidget {
  const TestSelectionScreen({super.key});

  Future<void> _navigateBack(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingControllerProvider.notifier).stopVoiceGuide();
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _selectTest(
    BuildContext context,
    WidgetRef ref,
    SessionProtocol protocol,
  ) async {
    await ref.read(onboardingControllerProvider.notifier).stopVoiceGuide();
    ref.read(preFlightControllerProvider.notifier).selectProtocol(protocol);
    if (!context.mounted) return;
    await context.push('/pre-flight');
  }

  Widget _iconForProtocol(SessionProtocol protocol) {
    return switch (protocol) {
      SessionProtocol.turning360 => ParkinIcons.tes360Illustration(size: 42),
      SessionProtocol.walkBackAndForth =>
        ParkinIcons.walkBackForthIllustration(size: 42),
      SessionProtocol.sitToStand =>
        ParkinIcons.sitToStandIllustration(size: 42),
    };
  }

  Key _keyForProtocol(SessionProtocol protocol) {
    return switch (protocol) {
      SessionProtocol.turning360 => const Key('test_card_turning360'),
      SessionProtocol.walkBackAndForth =>
        const Key('test_card_walkBackAndForth'),
      SessionProtocol.sitToStand => const Key('test_card_sitToStand'),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(
      onboardingControllerProvider.select((s) => s.isSpeakingGuide),
    );
    final selectedProtocol = ref.watch(
      preFlightControllerProvider.select((s) => s.checklist.protocol),
    );

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Semantics(
                        button: true,
                        label: 'Kembali ke beranda',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              key: const Key('select_test_back_button'),
                              onTap: () => _navigateBack(context, ref),
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
                          ? 'Hentikan panduan suara pilihan tes'
                          : 'Dengarkan panduan suara pilihan tes',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('select_test_voice_button'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => ref
                                .read(onboardingControllerProvider.notifier)
                                .toggleVoiceGuide(
                                  ClinicalCopy.testSelectionVoiceGuide,
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
                  ClinicalCopy.testSelectionTitle,
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  ClinicalCopy.testSelectionSubtitle,
                  style: AppTypography.bodyLarge(size: 14.5),
                ),
                const SizedBox(height: 18),
                for (final protocol in SessionProtocol.values) ...[
                  _ProtocolCard(
                    cardKey: _keyForProtocol(protocol),
                    protocol: protocol,
                    selected: selectedProtocol == protocol,
                    illustration: _iconForProtocol(protocol),
                    onTap: () => _selectTest(context, ref, protocol),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({
    required this.cardKey,
    required this.protocol,
    required this.selected,
    required this.illustration,
    required this.onTap,
  });

  final Key cardKey;
  final SessionProtocol protocol;
  final bool selected;
  final Widget illustration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${protocol.titleId}, durasi 2 menit. ${protocol.cardDescriptionId}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Material(
          color: AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected
                  ? AppColors.clinicalAzure
                  : AppColors.subtleBorderLight,
              width: selected ? 2.0 : 1.5,
            ),
          ),
          child: InkWell(
            key: cardKey,
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.iceSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: illustration,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                protocol.titleId,
                                style: AppTypography.cardTitle(size: 17.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.iceSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '2 Menit',
                                style: AppTypography.captionBadge(
                                  color: AppColors.onIceAzure,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          protocol.cardDescriptionId,
                          style: AppTypography.bodyLarge(size: 14.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ParkinIcons.chevronRight(
                    color: AppColors.royalNavy,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
