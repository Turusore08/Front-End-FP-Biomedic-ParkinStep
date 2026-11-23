import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../application/controllers/clinical_session_ui_state.dart';
import '../../../../di/clinical_session_providers.dart';
import '../../../../di/dashboard_providers.dart';
import '../../../../di/session_prep_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/enums/preview_gait_scenario.dart';
import '../../../../domain/enums/session_stage.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_highlight_prompt.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_progress_pill.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../../../widgets/design_system/parkin_state_cards.dart';
import '../../analytics/widgets/video_skeleton_player_card.dart';
import '../widgets/camera_standing_guide_overlay.dart';
import '../widgets/live_camera_backdrop.dart';

/// Unified video-based screening flow hosting:
/// - `readyToRecord`: clean camera framing + test guidance (NO live skeleton)
/// - `countdown`: 3-2-1 start preparation
/// - `recordingActive`: 2-minute guided video recording with timed text/voice cues
/// - `reviewRecorded`: confirmation to Retake ("Ulangi Rekaman") or Submit ("Kirim")
/// - `analyzingVideo`: post-recording 15 Hz YOLO pose extraction + LightGBM + video wipe
/// - `summaryReady`: completion summary with link to S-09 report
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
      final checklist = ref.read(preFlightControllerProvider).checklist;
      unawaited(
        _controller.startSession(
          protocol: checklist.protocol,
          medState: checklist.medState,
        ),
      );
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

  void _exitToPreviousOrHome() {
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
          unawaited(
            ref.read(homeDashboardControllerProvider.notifier).initialize(),
          );
        }
      },
    );

    final uiState = ref.watch(clinicalSessionControllerProvider);
    final fsm = uiState.fsm;

    if (uiState.isPausedByLifecycle) {
      return _PausedSessionView(
        onRestart: () {
          unawaited(
            _controller.startSession(
              protocol: fsm.protocol,
              medState: fsm.medState,
            ),
          );
        },
        onExit: () => context.go('/home'),
      );
    }

    switch (fsm.stage) {
      case SessionStage.readyToRecord:
        return _ReadyToRecordView(
          uiState: uiState,
          onCancel: _exitToPreviousOrHome,
          onToggleSound: _controller.toggleSound,
          onStartCountdown: _controller.startCountdown,
          onScenarioSelected: _controller.setPreviewScenario,
          onRetryOpenCamera: () {
            unawaited(
              _controller.startSession(
                protocol: fsm.protocol,
                medState: fsm.medState,
              ),
            );
          },
        );
      case SessionStage.countdown:
        return _CountdownView(
          uiState: uiState,
          onCancelCountdown: _controller.stopRecording,
        );
      case SessionStage.recordingActive:
        return _VideoRecordingView(
          uiState: uiState,
          onStopRecording: _controller.stopRecording,
          onToggleSound: _controller.toggleSound,
          onScenarioSelected: _controller.setPreviewScenario,
        );
      case SessionStage.reviewRecorded:
        return _ReviewRecordedView(
          uiState: uiState,
          onSubmitVideo: () => unawaited(_controller.submitVideoForAnalysis()),
          onRetake: () => unawaited(_controller.retakeRecording()),
        );
      case SessionStage.analyzingVideo:
        return _AnalyzingVideoView(
          uiState: uiState,
          onCancelAnalysis: () => unawaited(_controller.cancelAnalysis()),
        );
      case SessionStage.summaryReady:
        return _PostSessionSummaryView(
          uiState: uiState,
          onOpenReport: (String sessionId) =>
              context.push('/session-report/$sessionId'),
          onDeleteVideo: _controller.deleteCompletedSessionVideo,
          onGoHistory: () => context.go('/history'),
          onGoHome: () => context.go('/home'),
        );
    }
  }
}

class _ReadyToRecordView extends StatelessWidget {
  const _ReadyToRecordView({
    required this.uiState,
    required this.onCancel,
    required this.onToggleSound,
    required this.onStartCountdown,
    required this.onScenarioSelected,
    required this.onRetryOpenCamera,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onCancel;
  final VoidCallback onToggleSound;
  final VoidCallback onStartCountdown;
  final ValueChanged<PreviewGaitScenario> onScenarioSelected;
  final VoidCallback onRetryOpenCamera;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final hasError = uiState.errorMessage != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: LiveCameraBackdrop()),
              if (!hasError)
                Positioned.fill(
                  child: CameraStandingGuideOverlay(
                    key: const Key('camera_standing_guide_overlay'),
                    protocol: fsm.protocol,
                    isRecording: false,
                    topInsetFactor: uiState.isPreviewSimulation ? 0.20 : 0.13,
                    bottomInsetFactor: 0.39,
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
                            _TopCameraToolbar(
                              cancelKey: const Key('live_cancel_button'),
                              protocolLabel: fsm.protocol.shortLabelId,
                              soundEnabled: fsm.soundEnabled,
                              onCancel: onCancel,
                              onToggleSound: onToggleSound,
                            ),
                            if (uiState.isPreviewSimulation) ...[
                              const SizedBox(height: 10),
                              _PreviewScenarioBar(
                                scenarios: const <PreviewGaitScenario>[
                                  PreviewGaitScenario.normalGait,
                                  PreviewGaitScenario.confirmedFog,
                                ],
                                onSelected: onScenarioSelected,
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Expanded(child: SizedBox.shrink()),
                            if (hasError)
                              ParkinErrorLowLightCard(
                                key: const Key('session_error_card'),
                                retryKey: const Key('session_error_retry_button'),
                                title: ClinicalCopy.errorLowLightTitle,
                                description: uiState.errorMessage!,
                                ctaLabel: ClinicalCopy.errorLowLightCta,
                                onRetry: onRetryOpenCamera,
                              )
                            else
                              Container(
                                key: const Key('record_ready_card'),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.darkElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.subtleBorderDark,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      fsm.protocol.titleId,
                                      style: AppTypography.cardTitle(
                                        color: AppColors.pureWhite,
                                        size: 18.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      uiState.isOpeningCamera
                                          ? 'Membuka kamera belakang...'
                                          : fsm.protocol.readyInstructionId,
                                      style: AppTypography.bodyLarge(
                                        color: AppColors.darkMuted,
                                        size: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ParkinPrimaryPillButton(
                                      key: const Key('record_start_button'),
                                      label: 'Mulai Rekam (2 Menit)',
                                      leadingIcon: ParkinIcons.playTriangle(
                                        color: AppColors.clinicalAzure,
                                      ),
                                      isLoading: uiState.isOpeningCamera,
                                      onPressed: uiState.isOpeningCamera
                                          ? null
                                          : onStartCountdown,
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

class _CountdownView extends StatelessWidget {
  const _CountdownView({
    required this.uiState,
    required this.onCancelCountdown,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onCancelCountdown;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final cue = fsm.effectiveCue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('recording_countdown_screen'),
        backgroundColor: AppColors.midnightNavy,
        body: Stack(
          children: [
            const Positioned.fill(child: LiveCameraBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.midnightNavy.withValues(alpha: 0.72),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
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
                            Row(
                              children: [
                                _CompactCancelButton(
                                  buttonKey:
                                      const Key('countdown_cancel_button'),
                                  label: 'Batalkan',
                                  onPressed: onCancelCountdown,
                                ),
                              ],
                            ),
                            const Expanded(child: SizedBox.shrink()),
                            Center(
                              child: Semantics(
                                liveRegion: true,
                                label:
                                    'Mulai merekam dalam ${fsm.countdownRemainingSec} detik',
                                child: Container(
                                  width: 156,
                                  height: 156,
                                  decoration: BoxDecoration(
                                    color: AppColors.clinicalAzure,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.rhythmAqua,
                                      width: 4,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${fsm.countdownRemainingSec}',
                                    key: const Key('countdown_number_text'),
                                    style: AppTypography.displayTimer(
                                      color: AppColors.pureWhite,
                                      size: 56,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Bersiap: ${fsm.protocol.titleId}',
                              textAlign: TextAlign.center,
                              style: AppTypography.screenTitle(
                                color: AppColors.pureWhite,
                                size: 22,
                              ),
                            ),
                            const Expanded(child: SizedBox.shrink()),
                            ParkinHighlightPrompt(
                              key: const Key('countdown_preview_prompt'),
                              highlightWord: cue.highlightWord,
                              instructionTail: cue.instructionTail,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRecordingView extends StatelessWidget {
  const _VideoRecordingView({
    required this.uiState,
    required this.onStopRecording,
    required this.onToggleSound,
    required this.onScenarioSelected,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onStopRecording;
  final VoidCallback onToggleSound;
  final ValueChanged<PreviewGaitScenario> onScenarioSelected;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final cue = fsm.effectiveCue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: Stack(
          children: [
            const Positioned.fill(child: LiveCameraBackdrop()),
            Positioned.fill(
              child: CameraStandingGuideOverlay(
                key: const Key('camera_standing_guide_overlay'),
                protocol: fsm.protocol,
                isRecording: true,
                topInsetFactor: uiState.isPreviewSimulation ? 0.26 : 0.20,
                bottomInsetFactor: 0.30,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            (constraints.maxHeight - 32).clamp(0.0, 4000.0),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      key: const Key('recording_rec_badge'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.alertRed,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.pureWhite,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'REC · ${fsm.protocol.shortLabelId}',
                                              style: AppTypography.captionBadge(
                                                color: AppColors.pureWhite,
                                                weight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SoundIconButton(
                                  enabled: fsm.soundEnabled,
                                  onPressed: onToggleSound,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: _RecordingProgressOverlay(
                                key: const Key('live_progress_pill'),
                                elapsedSeconds: fsm.elapsedSec,
                                totalSeconds: fsm.protocol.durationSec,
                              ),
                            ),
                            if (uiState.isPreviewSimulation) ...[
                              const SizedBox(height: 10),
                              _PreviewScenarioBar(
                                scenarios: const <PreviewGaitScenario>[
                                  PreviewGaitScenario.normalGait,
                                  PreviewGaitScenario.confirmedFog,
                                ],
                                onSelected: onScenarioSelected,
                              ),
                            ],
                            const Expanded(child: SizedBox(height: 14)),
                            ParkinHighlightPrompt(
                              key: const Key('live_highlight_prompt'),
                              highlightWord: cue.highlightWord,
                              instructionTail: cue.instructionTail,
                            ),
                            const SizedBox(height: 14),
                            ParkinPrimaryPillButton(
                              key: const Key('record_stop_button'),
                              label: 'Selesai Rekam',
                              backgroundColor: AppColors.alertRed,
                              leadingIcon: ParkinIcons.stopSquare(
                                color: AppColors.alertRed,
                              ),
                              onPressed: onStopRecording,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRecordedView extends StatelessWidget {
  const _ReviewRecordedView({
    required this.uiState,
    required this.onSubmitVideo,
    required this.onRetake,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onSubmitVideo;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const Key('review_recorded_screen'),
        backgroundColor: AppColors.slateCanvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ClinicalCopy.reviewRecordedTitle,
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Periksa ringkasan rekaman sebelum mengirimnya ke Pose Extractor lokal.',
                  style: AppTypography.bodyLarge(size: 14.5),
                ),
                const SizedBox(height: 18),
                Container(
                  key: const Key('review_recorded_card'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.subtleBorderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          fsm.protocol.titleId,
                          style: AppTypography.captionBadge(
                            color: AppColors.onIceAzure,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Durasi Rekaman: ${fsm.recordedDurationSec} detik',
                        style: AppTypography.heroMetric(size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Status Obat: ${fsm.medState.labelId}',
                        style: AppTypography.bodyLarge(size: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ParkinIcons.offlineShield(
                            color: AppColors.emeraldDarkText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ClinicalCopy.reviewPrivacyGuarantee,
                              style: AppTypography.captionBadge(
                                color: AppColors.emeraldDarkText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!fsm.canSubmitVideo) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('short_video_warning'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.amberSoftBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.amberSoftBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ParkinIcons.alertTriangle(
                          color: AppColors.warningAmberText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ClinicalCopy.reviewShortVideoWarning,
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
                if (uiState.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.redSoftBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.alertRed),
                    ),
                    child: Text(
                      uiState.errorMessage!,
                      style: AppTypography.captionBadge(
                        color: AppColors.redDarkText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ParkinPrimaryPillButton(
                  key: const Key('record_submit_button'),
                  label: 'Kirim & Analisis Video',
                  leadingIcon: ParkinIcons.sendArrow(
                    color: fsm.canSubmitVideo
                        ? AppColors.clinicalAzure
                        : AppColors.mutedSlate,
                  ),
                  isLoading: uiState.isFinalizingVideoFile,
                  onPressed: (fsm.canSubmitVideo && !uiState.isFinalizingVideoFile)
                      ? onSubmitVideo
                      : null,
                ),
                const SizedBox(height: 12),
                ParkinSecondaryIceButton(
                  key: const Key('record_retake_button'),
                  title: 'Ulangi Rekaman',
                  subtitle: 'Hapus rekaman ini dan rekam ulang tes',
                  leadingIcon: ParkinIcons.retakeArrow(
                    color: AppColors.onIceAzure,
                  ),
                  onPressed: onRetake,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyzingVideoView extends StatelessWidget {
  const _AnalyzingVideoView({
    required this.uiState,
    required this.onCancelAnalysis,
  });

  final ClinicalSessionUiState uiState;
  final VoidCallback onCancelAnalysis;

  @override
  Widget build(BuildContext context) {
    final fsm = uiState.fsm;
    final frameLabel = fsm.analysisTotalFrames > 0
        ? '${fsm.analysisProcessedFrames} / ${fsm.analysisTotalFrames} frame'
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ParkinLoadingDspCard(
                    key: const Key('loading_dsp_card'),
                    title: ClinicalCopy.loadingDspTitle,
                    description: fsm.analysisStageLabel.isNotEmpty
                        ? fsm.analysisStageLabel
                        : ClinicalCopy.loadingDspBody,
                    progress: fsm.analysisProgress,
                    progressLabel: frameLabel,
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: OutlinedButton(
                      key: const Key('analysis_cancel_button'),
                      onPressed: onCancelAnalysis,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.subtleBorderDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Batalkan Analisis',
                        style: AppTypography.buttonLabel(
                          color: AppColors.pureWhite,
                          size: 15.5,
                        ),
                      ),
                    ),
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

class _PostSessionSummaryView extends StatelessWidget {
  const _PostSessionSummaryView({
    required this.uiState,
    required this.onOpenReport,
    required this.onDeleteVideo,
    required this.onGoHistory,
    required this.onGoHome,
  });

  final ClinicalSessionUiState uiState;
  final ValueChanged<String> onOpenReport;
  final Future<void> Function() onDeleteVideo;
  final VoidCallback onGoHistory;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final record = uiState.completedRecord;
    final protocol = record?.summary.protocol ?? uiState.fsm.protocol;
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
                  'Ringkasan ${protocol.titleId}',
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  record?.isSimulatedPreview ?? false
                      ? 'Data Simulasi Video · $medLabel'
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
                        (record != null && !record.videoSecurelyDeleted)
                            ? 'Video & skeleton tersimpan privat di HP untuk diputar ulang atau dihapus kapan saja.'
                            : 'Video sementara tidak tersimpan / telah dihapus dari perangkat.',
                        style: AppTypography.captionBadge(
                          color: AppColors.emeraldDarkText,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (record?.report != null) ...[
                  VideoSkeletonPlayerCard(
                    report: record!.report!,
                    onDeleteVideo: onDeleteVideo,
                  ),
                  const SizedBox(height: 14),
                ],
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
                'Kamera, suara, dan berkas sementara dilepas aman saat aplikasi berpindah ke latar belakang.',
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

class _TopCameraToolbar extends StatelessWidget {
  const _TopCameraToolbar({
    required this.cancelKey,
    required this.protocolLabel,
    required this.soundEnabled,
    required this.onCancel,
    required this.onToggleSound,
  });

  final Key cancelKey;
  final String protocolLabel;
  final bool soundEnabled;
  final VoidCallback onCancel;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: _CompactCancelButton(
            buttonKey: cancelKey,
            label: 'Batal',
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.iceSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                protocolLabel,
                style: AppTypography.captionBadge(
                  color: AppColors.onIceAzure,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SoundIconButton(
          enabled: soundEnabled,
          onPressed: onToggleSound,
        ),
      ],
    );
  }
}

class _CompactCancelButton extends StatelessWidget {
  const _CompactCancelButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label sesi skrining',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Material(
          color: AppColors.darkElevated,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: buttonKey,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ParkinIcons.arrowBack(color: AppColors.pureWhite),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppTypography.buttonLabel(
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
    );
  }
}

class _SoundIconButton extends StatelessWidget {
  const _SoundIconButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: enabled ? 'Matikan instruksi suara' : 'Aktifkan instruksi suara',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        child: Material(
          color: AppColors.darkElevated,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('record_sound_toggle'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: enabled
                  ? ParkinIcons.soundWave(color: AppColors.pureWhite, size: 22)
                  : ParkinIcons.soundMuted(color: AppColors.darkMuted, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingProgressOverlay extends StatelessWidget {
  const _RecordingProgressOverlay({
    super.key,
    required this.elapsedSeconds,
    required this.totalSeconds,
  });

  final int elapsedSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final total = totalSeconds <= 0 ? 120 : totalSeconds;
    final progress = (elapsedSeconds / total).clamp(0.0, 1.0);
    return Container(
      width: 184,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${ParkinProgressPill.formatDuration(elapsedSeconds)} / '
            '${ParkinProgressPill.formatDuration(total)}',
            style: AppTypography.captionBadge(
              color: AppColors.pureWhite,
              weight: FontWeight.w700,
              tabular: true,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: AppColors.rhythmAqua,
              backgroundColor: AppColors.pureWhite.withValues(alpha: 0.25),
            ),
          ),
        ],
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
