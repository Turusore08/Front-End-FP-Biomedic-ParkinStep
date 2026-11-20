import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../application/controllers/clinical_session_ui_state.dart';
import '../../../../application/state_machines/clinical_session_fsm.dart';
import '../../../../di/clinical_session_providers.dart';
import '../../../../di/dashboard_providers.dart';
import '../../../../di/session_prep_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/enums/alert_tier.dart';
import '../../../../domain/enums/preview_gait_scenario.dart';
import '../../../../domain/enums/session_stage.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_highlight_prompt.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_progress_pill.dart';
import '../../../widgets/design_system/parkin_risk_gauge.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../../../widgets/design_system/parkin_state_cards.dart';
import '../painters/skeleton_hud_painter.dart';

/// Unified live screening flow hosting S-05 (Framing & Calibration),
/// S-06 (60 FPS Live Skeleton HUD + Two-Tier Cueing), S-08 (10s Fall Guard),
/// R-27 State/LoadingDSP, State/ErrorLowLight, and immediate Session Summary.
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with WidgetsBindingObserver {
  late final ClinicalSessionController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(clinicalSessionControllerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final medState = ref.read(preFlightControllerProvider).checklist.medState;
      unawaited(_controller.startSession(medState: medState));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.handleLifecyclePaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.cancelTimersAndStreamsOnly();
    super.dispose();
  }

  void _exitToHomeOrPop() {
    _controller.cancelTimersAndStreamsOnly();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionStage>(
      clinicalSessionControllerProvider.select((s) => s.fsm.stage),
      (prev, next) {
        if (next == SessionStage.summaryReady &&
            prev != SessionStage.summaryReady) {
          unawaited(ref.read(homeDashboardControllerProvider.notifier).initialize());
        }
      },
    );

    final uiState = ref.watch(clinicalSessionControllerProvider);
    final fsm = uiState.fsm;

    if (uiState.isPausedByLifecycle) {
      return _PausedSessionView(
        onRestart: () {
          unawaited(_controller.startSession(medState: fsm.medState));
        },
        onExit: () => context.go('/home'),
      );
    }

    switch (fsm.stage) {
      case SessionStage.framingCheck:
      case SessionStage.calibratingStanding:
        return _FramingAndCalibrationView(
          uiState: uiState,
          onCancel: _exitToHomeOrPop,
          onRetryCalibration: _controller.retryCalibration,
          onScenarioSelected: _controller.setPreviewScenario,
        );
      case SessionStage.recordingActive:
        return _LiveRecordingHudView(
          uiState: uiState,
          onFinishTest: _controller.finishSessionEarly,
          onScenarioSelected: _controller.setPreviewScenario,
        );
      case SessionStage.fallGuardActive:
      case SessionStage.emergencyDispatched:
        return _FallGuardView(
          uiState: uiState,
          onCancelFallGuard: _controller.cancelFallGuard,
          onTriggerEmergencyNow: _controller.triggerEmergencyNow,
          onFinishAfterEmergency: _controller.finishSessionEarly,
        );
      case SessionStage.postSessionAnalyzing:
        return const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.midnightNavy,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: ParkinLoadingDspCard(
                    key: Key('loading_dsp_card'),
                    title: ClinicalCopy.loadingDspTitle,
                    description: ClinicalCopy.loadingDspBody,
                  ),
                ),
              ),
            ),
          ),
        );
      case SessionStage.summaryReady:
        return _PostSessionSummaryView(
          uiState: uiState,
          onOpenReport: (String sessionId) =>
              context.push('/session-report/$sessionId'),
          onGoHistory: () => context.go('/history'),
          onGoHome: () => context.go('/home'),
        );
    }
  }
}

class _FramingAndCalibrationView extends StatelessWidget {
  const _FramingAndCalibrationView({
    required this.uiState,
    required this.onCancel,
    required this.onRetryCalibration,
    required this.onScenarioSelected,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onCancel;
  final VoidCallback onRetryCalibration;
  final ValueChanged<PreviewGaitScenario> onScenarioSelected;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final frame = fsm.latestFrame;
    final confPct = ((frame?.lb6AvgConf ?? 0.0) * 100).round();
    final isCalibrating = fsm.stage == SessionStage.calibratingStanding;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: Stack(
            children: [
              // 60 FPS Live Skeleton Overlay + Alignment Reticle
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: SkeletonHudPainter(
                      frame: frame,
                      alertTier: fsm.alertTier,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 210,
                      height: 310,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isCalibrating
                              ? AppColors.normalEmerald
                              : AppColors.rhythmAqua,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            (constraints.maxHeight - 32).clamp(0.0, 4000.0),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top HUD Controls & LB6 Confidence Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Semantics(
                                    button: true,
                                    label: 'Batalkan sesi skrining',
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 56),
                                      child: Material(
                                        color: AppColors.darkElevated,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          key: const Key('live_cancel_button'),
                                          onTap: onCancel,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ParkinIcons.arrowBack(
                                                    color: AppColors.pureWhite,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Batal',
                                                    style:
                                                        AppTypography.buttonLabel(
                                                      color: AppColors.pureWhite,
                                                      size: 15.0,
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
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: confPct >= 20
                                          ? AppColors.emeraldSoftBg
                                          : AppColors.amberSoftBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Sendi LB6 $confPct%',
                                        style: AppTypography.captionBadge(
                                          color: confPct >= 20
                                              ? AppColors.emeraldDarkText
                                              : AppColors.amberDarkText,
                                          weight: FontWeight.w700,
                                          tabular: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (uiState.isPreviewSimulation) ...[
                              const SizedBox(height: 10),
                              _PreviewScenarioBar(
                                scenarios: const <PreviewGaitScenario>[
                                  PreviewGaitScenario.normalGait,
                                  PreviewGaitScenario.lowLightOcclusion,
                                  PreviewGaitScenario.confirmedFog,
                                ],
                                onSelected: onScenarioSelected,
                              ),
                            ],

                            const SizedBox(height: 20),
                            const Expanded(child: SizedBox.shrink()),

                            if (fsm.showLowLightError)
                              ParkinErrorLowLightCard(
                                key: const Key('low_light_error_card'),
                                retryKey: const Key('low_light_retry_button'),
                                title: ClinicalCopy.errorLowLightTitle,
                                description: ClinicalCopy.errorLowLightBody,
                                ctaLabel: ClinicalCopy.errorLowLightCta,
                                onRetry: onRetryCalibration,
                              )
                            else
                              Container(
                                key: const Key('calibration_status_card'),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.darkElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCalibrating
                                        ? AppColors.normalEmerald
                                        : AppColors.subtleBorderDark,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCalibrating
                                          ? '${ClinicalCopy.calibratingTitle} (${fsm.calibrationRemainingSec} dtk)'
                                          : ClinicalCopy.framingTitle,
                                      style: AppTypography.cardTitle(
                                        color: AppColors.pureWhite,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isCalibrating
                                          ? ClinicalCopy.calibratingBody
                                          : ClinicalCopy.framingBody,
                                      style: AppTypography.bodyLarge(
                                        color: AppColors.darkMuted,
                                        size: 14.5,
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveRecordingHudView extends StatelessWidget {
  const _LiveRecordingHudView({
    required this.uiState,
    required this.onFinishTest,
    required this.onScenarioSelected,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onFinishTest;
  final ValueChanged<PreviewGaitScenario> onScenarioSelected;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final frame = fsm.latestFrame;
    final compact = MediaQuery.sizeOf(context).height < 700;
    final viewportHeight = compact ? 190.0 : 250.0;

    final (badgeBg, badgeFg) = switch (fsm.alertTier) {
      AlertTier.gaitNormal => (AppColors.emeraldSoftBg, AppColors.emeraldDarkText),
      AlertTier.earlyWarning => (AppColors.amberSoftBg, AppColors.amberDarkText),
      AlertTier.fogConfirmed => (AppColors.alertRed, AppColors.pureWhite),
      AlertTier.fallGuard => (AppColors.alertRed, AppColors.pureWhite),
    };

    final (promptWord, promptTail) = switch (fsm.alertTier) {
      AlertTier.gaitNormal => (
          ClinicalCopy.livePromptNormalHighlight,
          ClinicalCopy.livePromptNormalTail,
        ),
      AlertTier.earlyWarning => (
          ClinicalCopy.livePromptWarningHighlight,
          ClinicalCopy.livePromptWarningTail,
        ),
      AlertTier.fogConfirmed || AlertTier.fallGuard => (
          ClinicalCopy.livePromptFogHighlight,
          ClinicalCopy.livePromptFogTail,
        ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Camera & 60 FPS Skeleton Overlay Viewport
                SizedBox(
                  height: viewportHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: SkeletonHudPainter(
                              frame: frame,
                              alertTier: fsm.alertTier,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkElevated,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.subtleBorderDark,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${ParkinProgressPill.formatDuration(fsm.elapsedSec)} / 02:00',
                                        style: AppTypography.captionBadge(
                                          color: AppColors.pureWhite,
                                          weight: FontWeight.w700,
                                          tabular: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    key: const Key('live_alert_badge'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        fsm.alertTier.badgeLabelId,
                                        style: AppTypography.captionBadge(
                                          color: badgeFg,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (frame?.isLowQualityWindow ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.amberSoftBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Kaki kurang terlihat, cek pencahayaan atau jarak kamera.',
                                  style: AppTypography.captionBadge(
                                    color: AppColors.amberDarkText,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lower Dark Elevated Clinical HUD Panel
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.darkElevated,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ParkinHighlightPrompt(
                        key: const Key('live_highlight_prompt'),
                        highlightWord: promptWord,
                        instructionTail: promptTail,
                      ),
                      const SizedBox(height: 16),
                      ParkinRiskGauge(
                        key: const Key('live_risk_gauge'),
                        calibratedRiskScore: frame?.calibratedRiskScore ?? 0.0,
                        onDarkSurface: true,
                      ),
                      const SizedBox(height: 14),
                      ParkinProgressPill(
                        key: const Key('live_progress_pill'),
                        elapsedSeconds: fsm.elapsedSec,
                        totalSeconds: ClinicalSessionFsm.sessionDurationSec,
                        onDarkSurface: true,
                      ),
                      if (uiState.isPreviewSimulation) ...[
                        const SizedBox(height: 14),
                        _PreviewScenarioBar(
                          scenarios: const <PreviewGaitScenario>[
                            PreviewGaitScenario.normalGait,
                            PreviewGaitScenario.confirmedFog,
                            PreviewGaitScenario.suddenFall,
                          ],
                          onSelected: onScenarioSelected,
                        ),
                      ],
                      const SizedBox(height: 18),
                      ParkinPrimaryPillButton(
                        key: const Key('live_finish_test_button'),
                        label: 'Selesaikan Tes',
                        backgroundColor: AppColors.alertRed,
                        leadingIcon: ParkinIcons.stopSquare(
                          color: AppColors.alertRed,
                        ),
                        onPressed: onFinishTest,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallGuardView extends StatelessWidget {
  const _FallGuardView({
    required this.uiState,
    required this.onCancelFallGuard,
    required this.onTriggerEmergencyNow,
    required this.onFinishAfterEmergency,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onCancelFallGuard;
  final VoidCallback onTriggerEmergencyNow;
  final VoidCallback onFinishAfterEmergency;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final dispatched = fsm.stage == SessionStage.emergencyDispatched;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('fall_guard_screen'),
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ClinicalCopy.fallGuardTopLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.captionBadge(
                    color: AppColors.darkMuted,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Semantics(
                    liveRegion: true,
                    label: dispatched
                        ? 'Peringatan darurat aktif'
                        : 'Hitung mundur ${fsm.fallCountdownSec} detik',
                    child: Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        color: AppColors.alertRed.withValues(alpha: 0.24),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 138,
                        height: 138,
                        decoration: const BoxDecoration(
                          color: AppColors.alertRed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dispatched ? 'DARURAT' : '${fsm.fallCountdownSec}',
                              style: AppTypography.displayTimer(
                                color: AppColors.pureWhite,
                                size: dispatched ? 24 : 44,
                              ),
                            ),
                            if (!dispatched)
                              Text(
                                'detik',
                                style: AppTypography.captionBadge(
                                  color: AppColors.pureWhite,
                                  weight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  dispatched
                      ? 'Peringatan Darurat Aktif'
                      : ClinicalCopy.fallGuardTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.screenTitle(
                    color: AppColors.pureWhite,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dispatched
                      ? 'Sirine lokal dibunyikan dan notifikasi darurat disiapkan untuk caregiver.'
                      : '${fsm.fallTriggerReason} ${ClinicalCopy.fallGuardBody}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge(
                    color: AppColors.darkMuted,
                    size: 15,
                  ),
                ),
                const SizedBox(height: 24),
                if (!dispatched) ...[
                  Semantics(
                    button: true,
                    label: 'Batalkan alarm darurat dan lanjutkan skrining',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 88),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.normalEmerald,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            key: const Key('fall_guard_im_ok_button'),
                            onTap: onCancelFallGuard,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: const BoxDecoration(
                                      color: AppColors.pureWhite,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: ParkinIcons.check(
                                      color: AppColors.emeraldDarkText,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      ClinicalCopy.fallGuardImOkCta,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.buttonLabel(
                                        color: AppColors.midnightNavy,
                                        size: 18.5,
                                      ),
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
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: OutlinedButton(
                      key: const Key('fall_guard_escalate_button'),
                      onPressed: onTriggerEmergencyNow,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0x99FFFFFF),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Hubungi Bantuan Sekarang',
                        style: AppTypography.buttonLabel(
                          color: AppColors.pureWhite,
                          size: 15.5,
                        ),
                      ),
                    ),
                  ),
                ] else
                  ParkinPrimaryPillButton(
                    key: const Key('emergency_finish_button'),
                    label: 'Hentikan Sirine & Selesai',
                    backgroundColor: AppColors.alertRed,
                    leadingIcon: ParkinIcons.stopSquare(
                      color: AppColors.alertRed,
                    ),
                    onPressed: onFinishAfterEmergency,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostSessionSummaryView extends StatelessWidget {
  const _PostSessionSummaryView({
    required this.uiState,
    required this.onOpenReport,
    required this.onGoHistory,
    required this.onGoHome,
  });

  final ClinicalSessionUiState uiState;
  final ValueChanged<String> onOpenReport;
  final VoidCallback onGoHistory;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final record = uiState.completedRecord;
    final fogPct =
        (record?.summary.fogPercentage ?? 0.0).toStringAsFixed(1).replaceAll(
              '.',
              ',',
            );
    final episodes = record?.summary.episodeCount ?? 0;
    final medLabel = record?.summary.medState.labelId ?? '-';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const Key('post_session_summary_screen'),
        backgroundColor: AppColors.slateCanvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ringkasan Sesi Tes 360°',
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  record?.isSimulatedPreview ?? false
                      ? 'Data Simulasi Kamera · $medLabel'
                      : 'Sesi Selesai · $medLabel',
                  style: AppTypography.captionBadge(
                    color: AppColors.onIceAzure,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.subtleBorderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$fogPct% Waktu FoG',
                        style: AppTypography.heroMetric(size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Jumlah Episode: $episodes · Status Obat: $medLabel',
                        style: AppTypography.bodyLarge(size: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Video sementara telah dihapus otomatis dari perangkat Anda.',
                        style: AppTypography.captionBadge(
                          color: AppColors.emeraldDarkText,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoftBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.amberSoftBorder),
                  ),
                  child: Text(
                    ClinicalCopy.medicalDisclaimer,
                    style: AppTypography.captionBadge(
                      color: AppColors.amberDarkText,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (record != null) ...[
                  ParkinPrimaryPillButton(
                    key: const Key('summary_open_report_button'),
                    label: 'Buka Grafik & Ekspor PDF (S-09)',
                    leadingIcon: ParkinIcons.navHistory(
                      color: AppColors.clinicalAzure,
                    ),
                    onPressed: () => onOpenReport(record.summary.sessionId),
                  ),
                  const SizedBox(height: 12),
                ],
                ParkinSecondaryIceButton(
                  key: const Key('summary_history_button'),
                  title: 'Lihat Riwayat Lengkap',
                  subtitle: 'Bandingkan tren sesi dan catatan obat Anda',
                  leadingIcon: ParkinIcons.navHistory(
                    color: AppColors.onIceAzure,
                  ),
                  onPressed: onGoHistory,
                ),
                const SizedBox(height: 12),
                ParkinSecondaryIceButton(
                  key: const Key('summary_home_button'),
                  title: 'Kembali ke Beranda',
                  subtitle: 'Tutup ringkasan dan kembali ke menu utama',
                  leadingIcon: ParkinIcons.navHome(color: AppColors.onIceAzure),
                  onPressed: onGoHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PausedSessionView extends StatelessWidget {
  const _PausedSessionView({
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sesi Dijeda Otomatis',
                textAlign: TextAlign.center,
                style: AppTypography.screenTitle(
                  color: AppColors.pureWhite,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Kamera dan cueing dilepas aman saat aplikasi berpindah ke latar belakang.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.darkMuted),
              ),
              const SizedBox(height: 24),
              ParkinPrimaryPillButton(
                label: 'Mulai Ulang Sesi',
                leadingIcon: ParkinIcons.playTriangle(
                  color: AppColors.clinicalAzure,
                ),
                onPressed: onRestart,
              ),
              const SizedBox(height: 12),
              ParkinSecondaryIceButton(
                title: 'Kembali ke Beranda',
                leadingIcon: ParkinIcons.navHome(color: AppColors.onIceAzure),
                onPressed: onExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewScenarioBar extends StatelessWidget {
  const _PreviewScenarioBar({
    required this.scenarios,
    required this.onSelected,
  });

  final List<PreviewGaitScenario> scenarios;
  final ValueChanged<PreviewGaitScenario> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < scenarios.length; i++) ...[
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: OutlinedButton(
                key: Key('preview_scenario_${scenarios[i].name}'),
                onPressed: () => onSelected(scenarios[i]),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.midnightNavy,
                  side: const BorderSide(color: AppColors.subtleBorderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Simulasi ${scenarios[i].labelId}',
                    style: AppTypography.captionBadge(
                      color: AppColors.pureWhite,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i != scenarios.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
