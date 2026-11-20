import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../application/controllers/metronome_ui_state.dart';
import '../../../../di/onboarding_providers.dart';
import '../../../../di/session_prep_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/metronome_config.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_pulse_metronome_ring.dart';

/// S-07: Standalone Rhythmic Auditory Stimulation (RAS) Metronome with
/// `64x64 dp` twin diamond steppers, tabular BPM/steps stats, and tactile presets.
class MetronomeRasScreen extends ConsumerStatefulWidget {
  const MetronomeRasScreen({super.key});

  @override
  ConsumerState<MetronomeRasScreen> createState() => _MetronomeRasScreenState();
}

class _MetronomeRasScreenState extends ConsumerState<MetronomeRasScreen>
    with WidgetsBindingObserver {
  late final MetronomeController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(metronomeControllerProvider.notifier);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.cancelTimersOnly();
    super.dispose();
  }

  Future<void> _navigateBack() async {
    _controller.stop();
    await ref.read(onboardingControllerProvider.notifier).stopVoiceGuide();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _openHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          ClinicalCopy.metronomeHelpTitle,
          style: AppTypography.cardTitle(size: 19),
        ),
        content: SingleChildScrollView(
          child: Text(
            ClinicalCopy.metronomeHelpBody,
            style: AppTypography.bodyLarge(size: 14.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(onboardingControllerProvider.notifier)
                  .toggleVoiceGuide(ClinicalCopy.metronomeVoiceGuide);
            },
            style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
            child: Text(
              'Dengarkan Suara',
              style: AppTypography.buttonLabel(
                color: AppColors.onIceAzure,
                size: 15.0,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(onboardingControllerProvider.notifier).stopVoiceGuide();
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
            child: Text(
              'Mengerti',
              style: AppTypography.buttonLabel(
                color: AppColors.royalNavy,
                size: 15.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeControllerProvider);
    final isRunning = state.isRunning;

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
                // Top bar: < Kembali on left, ? & Sound toggle on right
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
                              key: const Key('metronome_back_button'),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopActionIconButton(
                          key: const Key('metronome_help_button'),
                          semanticLabel: 'Panduan penggunaan metronom RAS',
                          active: false,
                          onPressed: _openHelpDialog,
                          icon: ParkinIcons.help(
                            color: AppColors.clinicalAzure,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _TopActionIconButton(
                          key: const Key('metronome_sound_toggle_button'),
                          semanticLabel: state.config.soundEnabled
                              ? 'Matikan suara ketukan metronom'
                              : 'Nyalakan suara ketukan metronom',
                          active: state.config.soundEnabled,
                          onPressed: _controller.toggleSound,
                          icon: state.config.soundEnabled
                              ? ParkinIcons.soundWave(
                                  color: AppColors.pureWhite,
                                  size: 22,
                                )
                              : ParkinIcons.soundMuted(
                                  color: AppColors.mutedNavSlate,
                                  size: 22,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Centerpiece: Concentric Pulse Ring + Diamond Controls
                ParkinPulseMetronomeRing(
                  formattedTime: state.formattedRemainingTime,
                  isRunning: isRunning,
                  pulseActive: state.pulseVisualActive,
                  canDecrement: state.config.bpm > MetronomeConfig.minBpm,
                  canIncrement: state.config.bpm < MetronomeConfig.maxBpm,
                  onDecrement: _controller.decrementBpm,
                  onIncrement: _controller.incrementBpm,
                ),
                const SizedBox(height: 14),

                Text(
                  isRunning
                      ? 'Ketukan aktif: angkat lutut ikuti irama'
                      : 'Tekan panah untuk atur tempo (40-120 BPM)',
                  textAlign: TextAlign.center,
                  style: AppTypography.captionBadge(
                    color: AppColors.mutedSlate,
                    weight: FontWeight.w600,
                  ),
                ),

                if (state.runState == MetronomeRunState.completed) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSoftBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.normalEmerald),
                      ),
                      child: Row(
                        children: [
                          ParkinIcons.check(
                            color: AppColors.emeraldDarkText,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sesi latihan metronom selesai.',
                              style: AppTypography.captionBadge(
                                color: AppColors.emeraldDarkText,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // 2-Column Tabular Metrics Row (Steps | BPM Metronom)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${state.displayedSteps}',
                              style: AppTypography.heroMetric(
                                color: AppColors.royalNavy,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              state.runState == MetronomeRunState.idle
                                  ? 'Estimasi Langkah'
                                  : 'Langkah Tercapai',
                              style: AppTypography.captionBadge(
                                color: AppColors.mutedSlate,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: AppColors.subtleBorderLight,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${state.config.bpm}',
                              style: AppTypography.heroMetric(
                                color: AppColors.royalNavy,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'BPM Metronom',
                              style: AppTypography.captionBadge(
                                color: AppColors.mutedSlate,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Tactile Duration Selector (1 Mnt / 2 Mnt / 5 Mnt)
                Row(
                  children: [
                    for (final sec in MetronomeConfig.allowedDurationsSec) ...[
                      Expanded(
                        child: _DurationPresetButton(
                          key: Key('metronome_dur_$sec'),
                          label: '${sec ~/ 60} Mnt',
                          selected: state.config.durationSeconds == sec,
                          enabled: !isRunning,
                          onPressed: () => _controller.selectDuration(sec),
                        ),
                      ),
                      if (sec != MetronomeConfig.allowedDurationsSec.last)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),

                const SizedBox(height: 22),

                ParkinPrimaryPillButton(
                  key: const Key('metronome_toggle_button'),
                  label: isRunning ? 'Hentikan Metronom' : 'Mulai Metronom',
                  backgroundColor:
                      isRunning ? AppColors.alertRed : AppColors.clinicalAzure,
                  leadingIcon: isRunning
                      ? ParkinIcons.stopSquare(color: AppColors.alertRed)
                      : ParkinIcons.playTriangle(
                          color: AppColors.clinicalAzure,
                        ),
                  onPressed: isRunning ? _controller.stop : _controller.start,
                ),

                if (state.runState == MetronomeRunState.paused ||
                    state.runState == MetronomeRunState.completed) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: TextButton(
                      key: const Key('metronome_reset_button'),
                      onPressed: _controller.reset,
                      child: Text(
                        'Ulangi Timer',
                        style: AppTypography.buttonLabel(
                          color: AppColors.onIceAzure,
                          size: 16.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionIconButton extends StatelessWidget {
  const _TopActionIconButton({
    super.key,
    required this.semanticLabel,
    required this.active,
    required this.onPressed,
    required this.icon,
  });

  final String semanticLabel;
  final bool active;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? AppColors.clinicalAzure : AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationPresetButton extends StatelessWidget {
  const _DurationPresetButton({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (enabled ? AppColors.clinicalAzure : AppColors.royalNavy)
        : AppColors.iceSurface;
    final fgColor = selected
        ? AppColors.pureWhite
        : (enabled ? AppColors.royalNavy : AppColors.mutedNavSlate);
    final borderColor = selected ? bgColor : AppColors.skyCard;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: 'Durasi latihan $label',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
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
    );
  }
}
