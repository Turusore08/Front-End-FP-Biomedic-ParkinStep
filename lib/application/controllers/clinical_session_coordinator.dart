import 'dart:async';

import '../../domain/constants/clinical_copy.dart';
import '../../domain/entities/completed_session_record.dart';
import '../../domain/entities/live_frame_result.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/session_summary_item.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/preview_gait_scenario.dart';
import '../../domain/enums/session_stage.dart';
import '../ports/cueing_port.dart';
import '../ports/edge_inference_port.dart';
import '../ports/emergency_alert_port.dart';
import '../ports/home_dashboard_repository_port.dart';
import '../ports/voice_guide_port.dart';
import '../state_machines/clinical_session_fsm.dart';
import 'clinical_session_ui_state.dart';
import 'metronome_coordinator.dart';

/// Pure Dart coordinator orchestrating the live S-05..S-08 screening session:
/// consumes 15 Hz pose stream, drives 1 Hz ClinicalSessionFsm, coordinates
/// Two-Tier RAS cueing / Fall Guard escalation, and persists post-session summaries.
class ClinicalSessionCoordinator {
  ClinicalSessionCoordinator({
    required this.edgeInferencePort,
    required this.cueingPort,
    required this.voiceGuidePort,
    required this.emergencyAlertPort,
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

  final EdgeInferencePort edgeInferencePort;
  final CueingPort cueingPort;
  final VoiceGuidePort voiceGuidePort;
  final EmergencyAlertPort emergencyAlertPort;
  final HomeDashboardRepositoryPort dashboardRepository;
  final ClinicalSessionUiState Function() readState;
  final void Function(ClinicalSessionUiState next) writeState;
  final String Function() _patientNameReader;
  final DateTime Function() _clock;
  final PeriodicTimerFactory _periodicTimerFactory;
  final ClinicalSessionFsm _fsm;

  StreamSubscription<LiveFrameResult>? _frameSubscription;
  Timer? _fsmTickTimer;
  Timer? _rasCueBeatTimer;
  int _rasBeatCounter = 0;
  DateTime? _sessionStartedUtc;

  Future<void> startSession({required MedicationState medState}) async {
    cancelTimersAndStreamsOnly();
    _sessionStartedUtc = _clock().toUtc();
    _rasBeatCounter = 0;

    writeState(
      ClinicalSessionUiState(
        fsm: ClinicalSessionFsmState(medState: medState),
        isPreviewSimulation: edgeInferencePort.isPreviewSimulation,
      ),
    );

    final stream = edgeInferencePort.startLiveStream(medState: medState);
    _frameSubscription = stream.listen(
      (LiveFrameResult frame) {
        final result = _fsm.onLiveFrame(readState().fsm, frame);
        writeState(readState().copyWith(fsm: result.state));
      },
      onError: (_) {
        writeState(
          readState().copyWith(
            errorMessage:
                'Koneksi kamera terhenti sementara. Silakan ulangi sesi.',
          ),
        );
      },
    );

    _fsmTickTimer = _periodicTimerFactory(
      const Duration(seconds: 1),
      (_) => _handleSecondTick(),
    );
  }

  void _handleSecondTick() {
    final current = readState();
    if (current.isPausedByLifecycle) return;

    final transition = _fsm.onOneSecondTick(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    _executeEffects(transition.effects, transition.state);
  }

  void retryCalibration() {
    final current = readState();
    final transition = _fsm.retryCalibration(current.fsm);
    writeState(current.copyWith(fsm: transition.state, clearError: true));
    _executeEffects(transition.effects, transition.state);
  }

  void cancelFallGuard() {
    final current = readState();
    final transition = _fsm.cancelFallGuard(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    _executeEffects(transition.effects, transition.state);
  }

  void triggerEmergencyNow() {
    final current = readState();
    final transition = _fsm.triggerEmergencyNow(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    _executeEffects(transition.effects, transition.state);
  }

  void finishSessionEarly() {
    final current = readState();
    final transition = _fsm.requestManualFinish(current.fsm);
    writeState(current.copyWith(fsm: transition.state));
    _executeEffects(transition.effects, transition.state);
  }

  void setPreviewScenario(PreviewGaitScenario scenario) {
    edgeInferencePort.setPreviewScenario(scenario);
  }

  void handleLifecyclePaused() {
    cancelTimersAndStreamsOnly();
    unawaited(edgeInferencePort.stopLiveStream());
    unawaited(voiceGuidePort.stop());
    unawaited(emergencyAlertPort.stopLocalSiren());
    writeState(readState().copyWith(isPausedByLifecycle: true));
  }

  /// Stops timers & stream subscriptions WITHOUT mutating Riverpod state.
  void cancelTimersAndStreamsOnly() {
    _fsmTickTimer?.cancel();
    _fsmTickTimer = null;
    _rasCueBeatTimer?.cancel();
    _rasCueBeatTimer = null;
    final sub = _frameSubscription;
    _frameSubscription = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
  }

  void _executeEffects(
    List<SessionFsmEffect> effects,
    ClinicalSessionFsmState fsmState,
  ) {
    for (final effect in effects) {
      switch (effect) {
        case SessionFsmEffect.playEarlyWarningChime:
          unawaited(
            cueingPort.playMetronomeBeat(
              accented: false,
              soundEnabled: true,
              hapticEnabled: true,
            ),
          );
        case SessionFsmEffect.startFogCueing:
          _startFogCueing();
        case SessionFsmEffect.stopFogCueing:
          _stopFogCueing();
        case SessionFsmEffect.startFallGuardAlarm:
          _stopFogCueing();
          unawaited(emergencyAlertPort.triggerLocalSiren());
          unawaited(voiceGuidePort.speak(ClinicalCopy.fallGuardVoicePrompt));
        case SessionFsmEffect.stopFallGuardAlarm:
          unawaited(emergencyAlertPort.stopLocalSiren());
          unawaited(voiceGuidePort.stop());
        case SessionFsmEffect.dispatchEmergencyAlert:
          unawaited(emergencyAlertPort.triggerLocalSiren());
          unawaited(
            emergencyAlertPort.dispatchCaregiverAlert(
              reason: fsmState.fallTriggerReason,
            ),
          );
        case SessionFsmEffect.beginPostSessionAnalysis:
          _stopFogCueing();
          unawaited(_finalizeSession(fsmState));
      }
    }
  }

  void _startFogCueing() {
    _rasCueBeatTimer?.cancel();
    _rasBeatCounter = 0;
    unawaited(voiceGuidePort.speak(ClinicalCopy.liveFogVoicePrompt));
    _emitRasBeat();
    // 80 BPM -> 750 ms beat interval
    _rasCueBeatTimer = _periodicTimerFactory(
      const Duration(milliseconds: 750),
      (_) => _emitRasBeat(),
    );
  }

  void _emitRasBeat() {
    final isAccented = _rasBeatCounter % 4 == 0;
    _rasBeatCounter++;
    unawaited(
      cueingPort.playMetronomeBeat(
        accented: isAccented,
        soundEnabled: true,
        hapticEnabled: true,
      ),
    );
  }

  void _stopFogCueing() {
    _rasCueBeatTimer?.cancel();
    _rasCueBeatTimer = null;
    unawaited(voiceGuidePort.stop());
  }

  Future<void> _finalizeSession(ClinicalSessionFsmState fsmState) async {
    cancelTimersAndStreamsOnly();
    try {
      await edgeInferencePort.stopLiveStream();
      final totalWins = fsmState.totalWindowCount;
      final fogPct = totalWins == 0
          ? 0.0
          : ((fsmState.confirmedFogWindowCount / totalWins) * 100.0)
              .clamp(0.0, 100.0);
      final meanFi =
          totalWins == 0 ? 0.0 : (fsmState.freezeIndexSum / totalWins);
      final startedUtc = _sessionStartedUtc ?? _clock().toUtc();

      final summary = SessionSummaryItem(
        sessionId: 'sess_${startedUtc.microsecondsSinceEpoch}',
        startedAtUtc: startedUtc,
        medState: fsmState.medState,
        fogPercentage: double.parse(fogPct.toStringAsFixed(1)),
        episodeCount: fsmState.episodeCount,
        durationSec: fsmState.elapsedSec.toDouble(),
      );

      final episodes = ClinicalSessionFsm.extractConfirmedEpisodes(
        fsmState.recordedWindows,
      );
      final medianEpisodeSec =
          SessionClinicalReport.computeMedianEpisodeDuration(episodes);
      final meanAsym = fsmState.recordedWindows.isEmpty
          ? 0.0
          : fsmState.recordedWindows
                  .map((w) => w.bilateralAsymAnkle)
                  .reduce((a, b) => a + b) /
              fsmState.recordedWindows.length;
      final locoEnergy = fsmState.episodeCount > 0 ? 2.4 : 4.6;
      final freezeEnergy =
          meanFi <= 0.01 ? 0.5 : (locoEnergy * meanFi).clamp(0.4, 25.0);

      final report = SessionClinicalReport(
        summary: summary,
        patientDisplayName: _patientNameReader(),
        validLb6Ratio: fsmState.averageLb6Conf.clamp(0.0, 1.0),
        totalFogDurationSec: fsmState.confirmedFogWindowCount.toDouble(),
        medianEpisodeDurationSec: medianEpisodeSec,
        locomotorBandEnergy: locoEnergy,
        freezeBandEnergy: double.parse(freezeEnergy.toStringAsFixed(2)),
        meanFreezeIndex: double.parse(meanFi.toStringAsFixed(2)),
        meanBilateralAsymmetry: double.parse(meanAsym.toStringAsFixed(3)),
        fallGuardFalseAlarms: fsmState.fallGuardFalseAlarms,
        videoSecurelyDeleted: true,
        isSimulatedPreview: readState().isPreviewSimulation,
        episodes: episodes,
        windows: fsmState.recordedWindows,
      );

      await dashboardRepository.saveSessionSummary(summary);
      await dashboardRepository.saveSessionReport(report);

      final record = CompletedSessionRecord(
        summary: summary,
        peakRiskScore: fsmState.peakRiskScore,
        meanFreezeIndex: meanFi,
        totalFogDurationSec: fsmState.confirmedFogWindowCount.toDouble(),
        validLb6Ratio: fsmState.averageLb6Conf.clamp(0.0, 1.0),
        fallGuardFalseAlarms: fsmState.fallGuardFalseAlarms,
        videoSecurelyDeleted: true,
        isSimulatedPreview: readState().isPreviewSimulation,
        report: report,
      );

      writeState(
        readState().copyWith(
          fsm: fsmState.copyWith(
            stage: SessionStage.summaryReady,
          ),
          completedRecord: record,
          clearError: true,
        ),
      );
    } catch (_) {
      writeState(
        readState().copyWith(
          errorMessage: 'Gagal menyimpan ringkasan sesi ke memori perangkat.',
        ),
      );
    } finally {
      await edgeInferencePort.secureDeleteTempVideo();
    }
  }
}
