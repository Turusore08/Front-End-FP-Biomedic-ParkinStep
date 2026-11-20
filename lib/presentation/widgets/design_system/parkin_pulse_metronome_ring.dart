import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';

/// Concentric RAS Metronome ring (`#1AEAD8` pulse ring + `#0077B6` core)
/// hosting the tabular countdown timer and two `64x64 dp` diamond steppers
/// for tremor-safe BPM adjustment without thin sliders.
class ParkinPulseMetronomeRing extends StatelessWidget {
  const ParkinPulseMetronomeRing({
    super.key,
    required this.formattedTime,
    required this.isRunning,
    required this.pulseActive,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String formattedTime;
  final bool isRunning;
  final bool pulseActive;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final glow =
        themeExt?.rhythmAquaGlow ?? ParkinThemeExt.standard.rhythmAquaGlow;
    final diamondShadow = themeExt?.diamondControlShadow ??
        ParkinThemeExt.standard.diamondControlShadow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize =
            math.min(272.0, constraints.maxWidth - 8).clamp(220.0, 272.0);
        final innerSize = ringSize - 38.0;

        return Center(
          child: AnimatedScale(
            scale: pulseActive ? 1.035 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                color: AppColors.rhythmAqua,
                shape: BoxShape.circle,
                boxShadow: glow,
              ),
              alignment: Alignment.center,
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: const BoxDecoration(
                  color: AppColors.clinicalAzure,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      liveRegion: isRunning,
                      label: 'Sisa waktu metronom $formattedTime',
                      child: SizedBox(
                        width: innerSize * 0.78,
                        height: 64,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formattedTime,
                            style: AppTypography.displayTimer(
                              color: AppColors.pureWhite,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DiamondStepButton(
                          key: const Key('metronome_bpm_down'),
                          semanticLabel: 'Kurangi tempo 5 BPM',
                          enabled: canDecrement,
                          shadow: diamondShadow,
                          icon: ParkinIcons.chevronDown(
                            color: AppColors.pureWhite,
                            size: 24,
                          ),
                          onPressed: onDecrement,
                        ),
                        const SizedBox(width: 20),
                        _DiamondStepButton(
                          key: const Key('metronome_bpm_up'),
                          semanticLabel: 'Tambah tempo 5 BPM',
                          enabled: canIncrement,
                          shadow: diamondShadow,
                          icon: ParkinIcons.chevronUp(
                            color: AppColors.pureWhite,
                            size: 24,
                          ),
                          onPressed: onIncrement,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiamondStepButton extends StatelessWidget {
  const _DiamondStepButton({
    super.key,
    required this.semanticLabel,
    required this.enabled,
    required this.shadow,
    required this.icon,
    required this.onPressed,
  });

  final String semanticLabel;
  final bool enabled;
  final List<BoxShadow> shadow;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        enabled ? AppColors.royalNavy : const Color(0xFF475569);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: enabled ? shadow : null,
                    ),
                  ),
                ),
                icon,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
