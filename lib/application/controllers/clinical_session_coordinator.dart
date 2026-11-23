import 'dart:async';

import '../../domain/entities/completed_session_record.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/session_summary_item.dart';
import '../../domain/entities/video_analysis_result.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/enums/session_protocol.dart';
import '../../domain/enums/session_stage.dart';
import '../ports/cueing_port.dart';
import '../ports/home_dashboard_repository_port.dart';
import '../ports/recorded_media_port.dart';
import '../ports/video_session_port.dart';
import '../ports/voice_guide_port.dart';
import '../state_machines/clinical_session_fsm.dart';
import 'clinical_session_ui_state.dart';
import 'metronome_coordinator.dart';

/// Pure Dart coordinator orchestrating the video-based screening flow:
/// opens camera preview (no live skeleton inference) -> 3-2-1 countdown ->
/// records 2-minute guided test -> review confirmation (Ulangi / Kirim) ->
/// post-recording Pose Extractor + LightGBM + persists video & synchronized pose
/// track privately for replay/export until deleted by the user.
class ClinicalSessionCoordinator {
  ClinicalSessionCoordinator({
    required this.videoSessionPort,
    required this.recordedMediaPort,
    required this.cueingPort,
    required this.voiceGuidePort,
    required this.dashboardRepository,
    required this.readState,
    required this.writeState,
    String Function()? patientNameReader,
    DateTime Function()? clock,
    PeriodicTimerFactory? periodicTimerFactory,
  })  : _patientNameReader = patientNameReader ?? _defaultPatientName,
        _clock = clock ?? DateTime.now,
        _periodicTimerFactory = periodicTimerFactory ?? Timer.periodic,
        _fsm = const ClinicalSessionFsm();

  static String _defaultPatientName() => 'Pengguna';

  final VideoSessionPort videoSessionPort;
  final RecordedMediaPort recordedMediaPort;
  final CueingPort cueingPort;
  final VoiceGuidePort voiceGuidePort;
  final HomeDashboardRepositoryPort dashboardRepository;
  final ClinicalSessionUiState Function() readState;
  final void Function(ClinicalSessionUiState next) writeState;
  final String Function() _patientNameReader;
  final DateTime Function() _clock;
  final PeriodicTimerFactory _periodicTimerFactory;
  final ClinicalSessionFsm _fsm;

  Timer? _fsmTickTimer;
  DateTime? _sessionStartedUtc;
  Future<void>? _pendingStopRecording;
  int _sessionGeneration = 0;

  Future<void> startSession({
    required SessionProtocol protocol,
    required MedicationState medState,
  }) async {
    _cancelTimersOnly();
    _sessionGeneration++;
    final gen = _sessionGeneration;
    _sessionStartedUtc = _clock().toUtc();

    final prevVideoPath = readState().fsm.recordedVideoPath;
    if (prevVideoPath != null) {
      unawaited(videoSessionPort.secureDeleteVideo(prevVideoPath));
    }

    writeState(
      ClinicalSessionUiState(
        fsm: ClinicalSessionFsmState(
          protocol: protocol,
          medState: medState,
          activeCue: protocol.cueForElapsed(0),
        ),
        isPreviewSimulation: videoSessionPort.isPreviewSimulation,
        isOpeningCamera: true,
      ),
    );

    try {
      await videoSessionPort.openCameraPreview();
      if (gen != _sessionGeneration) return;
      writeState(readState().copyWith(isOpeningCamera: false, clearError: true));
    } catch (_) {
      if (gen != _sessionGeneration) return;
      writeState(
        readState().copyWith(
          isOpeningCamera: false,
          errorMessage:
              'Kamera tidak dapat dibuka. Pastikan izin kamera aktif dan coba lagi.',
        ),
      );
    }
  }

  void startCountdown() {
    final current = readState();
    if (current.isOpeningCamera || current.isPausedByLifecycle) return;
    final transition = _fsm.requestStartCountdown(current.fsm);
    writeState(current.copyWith(fsm: transition.state, clearError: true));
    _executeEffects(transition.effects, transition.state);

    _fsmTickTimer?.cancel();
    _fsmTickTimer = _periodicTimerFactory(
      const Duration(seconds: 1),
      (_) => _handleSecondTick(),
    );
  }

  void stopRecording() {
    _fsmTickTimer?.cancel();
    _fsmTickTimer = null;
    final current = readState();
    final transition = _fsm.requestStopRecording(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    _executeEffects(transition.effects, transition.state);
  }

  Future<void> retakeRecording() async {
    _fsmTickTimer?.cancel();
    _fsmTickTimer = null;
    final pendingStop = _pendingStopRecording;
    if (pendingStop != null) {
      await pendingStop.catchError((Object _) {});
    }

    final current = readState();
    final videoToDelete = current.fsm.recordedVideoPath;
    final transition = _fsm.requestRetake(current.fsm);
    if (transition.state == current.fsm) return;

    _sessionGeneration++;
    final gen = _sessionGeneration;
    videoSessionPort.cancelAnalysis();

    writeState(
      current.copyWith(
        fsm: transition.state,
        isOpeningCamera: true,
        clearCompletedRecord: true,
        clearError: true,
      ),
    );
    _executeEffects(
      transition.effects,
      transition.state,
      overrideVideoPath: videoToDelete,
    );

    try {
      await videoSessionPort.openCameraPreview();
      if (gen != _sessionGeneration) return;
      writeState(readState().copyWith(isOpeningCamera: false));
    } catch (_) {
      if (gen != _sessionGeneration) return;
      writeState(
        readState().copyWith(
          isOpeningCamera: false,
          errorMessage: 'Gagal membuka kembali kamera untuk rekam ulang.',
        ),
      );
    }
  }

  Future<void> submitVideoForAnalysis() async {
    final pendingStop = _pendingStopRecording;
    if (pendingStop != null) {
      await pendingStop.catchError((Object _) {});
    }

    final current = readState();
    final transition = _fsm.requestSubmitVideo(current.fsm);
    if (transition.state == current.fsm) return;

    writeState(current.copyWith(fsm: transition.state, clearError: true));
    _executeEffects(transition.effects, transition.state);
  }

  Future<void> cancelAnalysis() async {
    videoSessionPort.cancelAnalysis();
    await retakeRecording();
  }

  void toggleSound() {
    final current = readState();
    final nextFsm = _fsm.toggleSound(current.fsm);
    writeState(current.copyWith(fsm: nextFsm));
    if (!nextFsm.soundEnabled) {
      unawaited(voiceGuidePort.stop());
    }
  }

  void setPreviewScenario(PreviewGaitScenario scenario) {
    videoSessionPort.setPreviewScenario(scenario);
  }

  /// Securely overwrites & deletes the completed session's stored MP4 & pose track.
  Future<void> deleteCompletedSessionVideo() async {
    final current = readState();
    final record = current.completedRecord;
    final report = record?.report;
    if (record == null || report == null) return;

    await recordedMediaPort.deleteSessionMedia(
      videoPath: report.recordedVideoPath,
      poseTrackPath: report.poseTrackPath,
    );

    final updatedReport = report.copyWith(
      videoSecurelyDeleted: true,
      clearRecordedVideoPath: true,
      clearPoseTrackPath: true,
      clearPoseTrack: true,
    );
    await dashboardRepository.saveSessionReport(updatedReport);

    final updatedRecord = CompletedSessionRecord(
      summary: record.summary,
      peakRiskScore: record.peakRiskScore,
      meanFreezeIndex: record.meanFreezeIndex,
      totalFogDurationSec: record.totalFogDurationSec,
      validLb6Ratio: record.validLb6Ratio,
      fallGuardFalseAlarms: record.fallGuardFalseAlarms,
      videoSecurelyDeleted: true,
      isSimulatedPreview: record.isSimulatedPreview,
      report: updatedReport,
    );

    writeState(readState().copyWith(completedRecord: updatedRecord));
  }

  void handleLifecyclePaused() {
    _cancelTimersOnly();
    _sessionGeneration++;
    videoSessionPort.cancelAnalysis();
    unawaited(voiceGuidePort.stop());
    final current = readState();
    final videoPath = current.fsm.recordedVideoPath;
    unawaited(videoSessionPort.closeCameraPreview());
    if (videoPath != null) {
      unawaited(videoSessionPort.secureDeleteVideo(videoPath));
    }
    writeState(current.copyWith(isPausedByLifecycle: true));
  }

  /// Stops timers & releases active camera/TTS resources without mutating state during dispose.
  void cancelTimersAndStreamsOnly() {
    _cancelTimersOnly();
    _sessionGeneration++;
    videoSessionPort.cancelAnalysis();
    unawaited(voiceGuidePort.stop());
    unawaited(videoSessionPort.closeCameraPreview());
  }

  void _cancelTimersOnly() {
    _fsmTickTimer?.cancel();
    _fsmTickTimer = null;
  }

  void _handleSecondTick() {
    final current = readState();
    if (current.isPausedByLifecycle) return;

    final transition = _fsm.onOneSecondTick(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    if (transition.state.stage == SessionStage.reviewRecorded) {
      _cancelTimersOnly();
    }
    _executeEffects(transition.effects, transition.state);
  }

  void _executeEffects(
    List<SessionFsmEffect> effects,
    ClinicalSessionFsmState fsmState, {
    String? overrideVideoPath,
  }) {
    for (final effect in effects) {
      switch (effect) {
        case SessionFsmEffect.playCountdownBeep:
          unawaited(
            cueingPort.playMetronomeBeat(
              accented: false,
              soundEnabled: fsmState.soundEnabled,
              hapticEnabled: true,
            ),
          );
        case SessionFsmEffect.speakCue:
          if (fsmState.soundEnabled) {
            unawaited(voiceGuidePort.speak(fsmState.effectiveCue.voicePrompt));
          }
        case SessionFsmEffect.stopVoice:
          unawaited(voiceGuidePort.stop());
        case SessionFsmEffect.startVideoRecording:
          unawaited(_startVideoCapture(_sessionGeneration));
        case SessionFsmEffect.stopVideoRecording:
          _pendingStopRecording = _stopVideoCapture(_sessionGeneration);
        case SessionFsmEffect.playCompletionChime:
          unawaited(
            cueingPort.playCompletionChime(
              soundEnabled: fsmState.soundEnabled,
              hapticEnabled: true,
            ),
          );
        case SessionFsmEffect.deleteTempVideo:
          final path = overrideVideoPath ?? fsmState.recordedVideoPath;
          if (path != null) {
            unawaited(videoSessionPort.secureDeleteVideo(path));
          }
        case SessionFsmEffect.beginVideoAnalysis:
          unawaited(_runPostRecordingAnalysis(_sessionGeneration));
      }
    }
  }

  Future<void> _startVideoCapture(int gen) async {
    try {
      await videoSessionPort.startRecording();
    } catch (_) {
      if (gen != _sessionGeneration) return;
      _cancelTimersOnly();
      writeState(
        readState().copyWith(
          fsm: readState().fsm.copyWith(stage: SessionStage.readyToRecord),
          errorMessage: 'Gagal memulai perekaman video. Silakan coba lagi.',
        ),
      );
    }
  }

  Future<void> _stopVideoCapture(int gen) async {
    writeState(readState().copyWith(isFinalizingVideoFile: true));
    try {
      final path = await videoSessionPort.stopRecording();
      await videoSessionPort.closeCameraPreview();
      if (gen != _sessionGeneration) {
        await videoSessionPort.secureDeleteVideo(path);
        return;
      }
      final current = readState();
      writeState(
        current.copyWith(
          fsm: _fsm.attachRecordedVideoPath(current.fsm, path),
          isFinalizingVideoFile: false,
        ),
      );
    } catch (_) {
      await videoSessionPort.closeCameraPreview();
      if (gen != _sessionGeneration) return;
      writeState(
        readState().copyWith(
          isFinalizingVideoFile: false,
          errorMessage: 'Gagal menyimpan video rekaman. Silakan ulangi.',
        ),
      );
    } finally {
      _pendingStopRecording = null;
    }
  }

  Future<void> _runPostRecordingAnalysis(int gen) async {
    final current = readState();
    final videoPath = current.fsm.recordedVideoPath;
    if (videoPath == null || videoPath.isEmpty) {
      writeState(
        current.copyWith(
          fsm: current.fsm.copyWith(stage: SessionStage.readyToRecord),
          errorMessage: 'Berkas video rekaman tidak ditemukan. Silakan ulangi.',
        ),
      );
      unawaited(videoSessionPort.openCameraPreview());
      return;
    }

    try {
      final result = await videoSessionPort.analyzeRecordedVideo(
        videoPath: videoPath,
        protocol: current.fsm.protocol,
        fallbackDurationSec: current.fsm.recordedDurationSec.toDouble(),
        onProgress: (VideoAnalysisProgress progress) {
          if (gen != _sessionGeneration) return;
          final latest = readState();
          writeState(
            latest.copyWith(
              fsm: latest.fsm.copyWith(
                analysisProgress: progress.fraction,
                clearAnalysisProgress: progress.fraction == null,
                analysisProcessedFrames: progress.processedFrames,
                analysisTotalFrames: progress.totalFrames,
                analysisStageLabel: progress.stageLabelId,
              ),
            ),
          );
        },
      );

      if (gen != _sessionGeneration) {
        await videoSessionPort.secureDeleteVideo(videoPath);
        return;
      }

      final startedUtc = _sessionStartedUtc ?? _clock().toUtc();
      final sessionId = 'sess_${startedUtc.microsecondsSinceEpoch}';
      final latestFsm = readState().fsm;
      final summary = SessionSummaryItem(
        sessionId: sessionId,
        startedAtUtc: startedUtc,
        protocol: latestFsm.protocol,
        medState: latestFsm.medState,
        fogPercentage: result.fogPercentage,
        episodeCount: result.episodeCount,
        durationSec: result.durationSec,
      );

      String? storedVideoPath;
      String? storedPosePath;
      var isDeleted = result.videoSecurelyDeleted;
      if (result.poseTrack != null) {
        final saved = await recordedMediaPort.saveSessionMedia(
          sessionId: sessionId,
          sourceVideoPath: videoPath,
          poseTrack: result.poseTrack!,
        );
        storedVideoPath = saved.videoPath;
        storedPosePath = saved.poseTrackPath;
        isDeleted = false;
      }

      final report = SessionClinicalReport(
        summary: summary,
        patientDisplayName: _patientNameReader(),
        classifierUsed: 'LIGHTGBM_FFT',
        thresholdUsed: result.thresholdUsed,
        validLb6Ratio: result.validLb6Ratio,
        totalFogDurationSec: result.totalFogDurationSec,
        medianEpisodeDurationSec: result.medianEpisodeDurationSec,
        locomotorBandEnergy: result.locomotorBandEnergy,
        freezeBandEnergy: result.freezeBandEnergy,
        meanFreezeIndex: result.meanFreezeIndex,
        meanBilateralAsymmetry: result.meanBilateralAsymmetry,
        fallGuardFalseAlarms: 0,
        videoSecurelyDeleted: isDeleted,
        isSimulatedPreview: readState().isPreviewSimulation,
        recordedVideoPath: storedVideoPath,
        poseTrackPath: storedPosePath,
        poseTrack: result.poseTrack,
        episodes: result.episodes,
        windows: result.windows,
      );

      await dashboardRepository.saveSessionSummary(summary);
      await dashboardRepository.saveSessionReport(report);

      final record = CompletedSessionRecord(
        summary: summary,
        peakRiskScore: result.peakRiskScore,
        meanFreezeIndex: result.meanFreezeIndex,
        totalFogDurationSec: result.totalFogDurationSec,
        validLb6Ratio: result.validLb6Ratio,
        fallGuardFalseAlarms: 0,
        videoSecurelyDeleted: isDeleted,
        isSimulatedPreview: readState().isPreviewSimulation,
        report: report,
      );

      if (gen != _sessionGeneration) return;

      writeState(
        readState().copyWith(
          fsm: latestFsm.copyWith(
            stage: SessionStage.summaryReady,
            clearVideoPath: true,
          ),
          completedRecord: record,
          clearError: true,
        ),
      );
    } catch (_) {
      await videoSessionPort.secureDeleteVideo(videoPath);
      if (gen != _sessionGeneration) return;
      final latest = readState();
      writeState(
        latest.copyWith(
          fsm: latest.fsm.copyWith(
            stage: SessionStage.readyToRecord,
            countdownRemainingSec: ClinicalSessionFsm.countdownDurationSec,
            elapsedSec: 0,
            recordedDurationSec: 0,
            clearVideoPath: true,
          ),
          errorMessage:
              'Gagal mengekstrak pose dari video. Pastikan pencahayaan terang lalu rekam ulang.',
        ),
      );
      unawaited(videoSessionPort.openCameraPreview());
    }
  }
}
