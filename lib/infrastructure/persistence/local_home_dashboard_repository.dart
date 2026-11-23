import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/home_dashboard_repository_port.dart';
import '../../domain/entities/fog_episode_item.dart';
import '../../domain/entities/home_dashboard_summary.dart';
import '../../domain/entities/medication_log.dart';
import '../../domain/entities/session_clinical_report.dart';
import '../../domain/entities/session_summary_item.dart';
import '../../domain/entities/window_prediction_item.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/session_protocol.dart';
import '../../domain/enums/session_sync_status.dart';
import '../../domain/errors/dashboard_failure.dart';

/// Offline-first SharedPreferences adapter for S-03 dashboard state,
/// recent sessions, medication logs, and reminder dismissals.
class LocalHomeDashboardRepository implements HomeDashboardRepositoryPort {
  const LocalHomeDashboardRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'parkinstep_dashboard_v1';
  static const String reportsStorageKey = 'parkinstep_dashboard_reports_v1';
  static const int _maxStoredSessions = 100;
  static const int _maxStoredMedicationLogs = 200;

  @override
  Future<HomeDashboardSummary> loadSummary() async {
    final rawJson = _prefs.getString(storageKey);
    if (rawJson == null || rawJson.isEmpty) {
      return const HomeDashboardSummary();
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, Object?>) {
        return const HomeDashboardSummary();
      }

      final sessions = _decodeSessions(decoded['recent_sessions'])
        ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

      final logs = _decodeMedicationLogs(decoded['medication_logs'])
        ..sort((a, b) => b.takenAtUtc.compareTo(a.takenAtUtc));

      final dismissedRaw = decoded['dismissed_reminder_date_iso'];
      final dismissedDate =
          dismissedRaw is String && dismissedRaw.isNotEmpty ? dismissedRaw : null;

      return HomeDashboardSummary(
        recentSessions: List<SessionSummaryItem>.unmodifiable(sessions),
        medicationLogs: List<MedicationLog>.unmodifiable(logs),
        dismissedReminderDateIso: dismissedDate,
      );
    } catch (_) {
      // Corrupt or unreadable JSON falls back cleanly to an empty summary.
      return const HomeDashboardSummary();
    }
  }

  @override
  Future<HomeDashboardSummary> addMedicationLog(MedicationLog log) async {
    final current = await loadSummary();
    final updatedLogs = <MedicationLog>[
      log,
      ...current.medicationLogs.where((item) => item.logId != log.logId),
    ]..sort((a, b) => b.takenAtUtc.compareTo(a.takenAtUtc));

    final boundedLogs = updatedLogs.take(_maxStoredMedicationLogs).toList();
    final next = current.copyWith(
      medicationLogs: List<MedicationLog>.unmodifiable(boundedLogs),
    );
    await _persist(next);
    return next;
  }

  @override
  Future<HomeDashboardSummary> saveSessionSummary(
    SessionSummaryItem session,
  ) async {
    final current = await loadSummary();
    final updatedSessions = <SessionSummaryItem>[
      session,
      ...current.recentSessions.where(
        (item) => item.sessionId != session.sessionId,
      ),
    ]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    final boundedSessions = updatedSessions.take(_maxStoredSessions).toList();
    final next = current.copyWith(
      recentSessions: List<SessionSummaryItem>.unmodifiable(boundedSessions),
    );
    await _persist(next);
    return next;
  }

  @override
  Future<HomeDashboardSummary> dismissReminderForDate(
    String localDateIso,
  ) async {
    final current = await loadSummary();
    final next = current.copyWith(dismissedReminderDateIso: localDateIso);
    await _persist(next);
    return next;
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(storageKey);
    await _prefs.remove(reportsStorageKey);
  }

  @override
  Future<void> saveSessionReport(SessionClinicalReport report) async {
    try {
      final rawJson = _prefs.getString(reportsStorageKey);
      final Map<String, Object?> reportMap;
      if (rawJson != null && rawJson.isNotEmpty) {
        final Object? decoded = jsonDecode(rawJson);
        reportMap = decoded is Map<String, Object?>
            ? Map<String, Object?>.of(decoded)
            : <String, Object?>{};
      } else {
        reportMap = <String, Object?>{};
      }

      reportMap[report.summary.sessionId] = _encodeReport(report);

      // Keep at most 40 detailed window traces in SharedPreferences cleanly.
      if (reportMap.length > 40) {
        final keys = reportMap.keys.toList();
        for (var i = 0; i < keys.length - 40; i++) {
          reportMap.remove(keys[i]);
        }
      }

      final ok = await _prefs.setString(
        reportsStorageKey,
        jsonEncode(reportMap),
      );
      if (!ok) {
        throw const DashboardStorageFailure();
      }
    } catch (e) {
      if (e is DashboardFailure) rethrow;
      throw const DashboardStorageFailure();
    }
  }

  @override
  Future<SessionClinicalReport?> loadSessionReport(String sessionId) async {
    final rawJson = _prefs.getString(reportsStorageKey);
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, Object?>) return null;
      final Object? entry = decoded[sessionId];
      if (entry is! Map<String, Object?>) return null;
      return _decodeReport(entry);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _encodeReport(SessionClinicalReport r) {
    final s = r.summary;
    return <String, Object?>{
      'summary': <String, Object?>{
        'session_id': s.sessionId,
        'started_at_utc': s.startedAtUtc.toUtc().toIso8601String(),
        'protocol': s.protocol.storageValue,
        'med_state': s.medState.storageValue,
        'fog_percentage': s.fogPercentage,
        'episode_count': s.episodeCount,
        'duration_sec': s.durationSec,
        'sync_status': s.syncStatus.storageValue,
      },
      'patient_display_name': r.patientDisplayName,
      'classifier_used': r.classifierUsed,
      'model_bundle_version': r.modelBundleVersion,
      'threshold_used': r.thresholdUsed,
      'valid_lb6_ratio': r.validLb6Ratio,
      'total_fog_duration_sec': r.totalFogDurationSec,
      'median_episode_duration_sec': r.medianEpisodeDurationSec,
      'locomotor_band_energy': r.locomotorBandEnergy,
      'freeze_band_energy': r.freezeBandEnergy,
      'mean_freeze_index': r.meanFreezeIndex,
      'mean_bilateral_asymmetry': r.meanBilateralAsymmetry,
      'fall_guard_false_alarms': r.fallGuardFalseAlarms,
      'video_securely_deleted': r.videoSecurelyDeleted,
      'is_simulated_preview': r.isSimulatedPreview,
      'recorded_video_path': r.recordedVideoPath,
      'pose_track_path': r.poseTrackPath,
      'episodes': r.episodes
          .map(
            (ep) => <String, Object?>{
              'episode_index': ep.episodeIndex,
              'start_sec': ep.startSec,
              'end_sec': ep.endSec,
              'peak_calibrated_score': ep.peakCalibratedScore,
              'mean_freeze_index': ep.meanFreezeIndex,
            },
          )
          .toList(),
      'windows': r.windows
          .map(
            (w) => <String, Object?>{
              'window_idx': w.windowIdx,
              'start_sec': w.startSec,
              'end_sec': w.endSec,
              'raw_prob': w.rawProb,
              'calibrated_score': w.calibratedScore,
              'pred_raw': w.predRaw,
              'pred_postprocessed': w.predPostprocessed,
              'freeze_index_ankle': w.freezeIndexAnkle,
              'bilateral_asym_ankle': w.bilateralAsymAnkle,
              'low_quality_flag': w.lowQualityFlag,
            },
          )
          .toList(),
    };
  }

  static SessionClinicalReport? _decodeReport(Map<String, Object?> map) {
    final summaryList = _decodeSessions(<Object?>[map['summary']]);
    if (summaryList.isEmpty) return null;
    final episodes = <FogEpisodeItem>[];
    final epRaw = map['episodes'];
    if (epRaw is List<Object?>) {
      for (final item in epRaw) {
        if (item is! Map<String, Object?>) continue;
        final idx = _readInt(item['episode_index']);
        final start = _readDouble(item['start_sec']);
        final end = _readDouble(item['end_sec']);
        final peak = _readDouble(item['peak_calibrated_score']);
        final fi = _readDouble(item['mean_freeze_index']);
        if (idx == null || start == null || end == null || peak == null) {
          continue;
        }
        episodes.add(
          FogEpisodeItem(
            episodeIndex: idx,
            startSec: start,
            endSec: end,
            peakCalibratedScore: peak,
            meanFreezeIndex: fi ?? 0.0,
          ),
        );
      }
    }

    final windows = <WindowPredictionItem>[];
    final winRaw = map['windows'];
    if (winRaw is List<Object?>) {
      for (final item in winRaw) {
        if (item is! Map<String, Object?>) continue;
        final wIdx = _readInt(item['window_idx']);
        final start = _readDouble(item['start_sec']);
        final end = _readDouble(item['end_sec']);
        final rawProb = _readDouble(item['raw_prob']);
        final cal = _readDouble(item['calibrated_score']);
        if (wIdx == null ||
            start == null ||
            end == null ||
            rawProb == null ||
            cal == null) {
          continue;
        }
        windows.add(
          WindowPredictionItem(
            windowIdx: wIdx,
            startSec: start,
            endSec: end,
            rawProb: rawProb,
            calibratedScore: cal,
            predRaw: item['pred_raw'] == true,
            predPostprocessed: item['pred_postprocessed'] == true,
            freezeIndexAnkle: _readDouble(item['freeze_index_ankle']) ?? 0.0,
            bilateralAsymAnkle:
                _readDouble(item['bilateral_asym_ankle']) ?? 0.0,
            lowQualityFlag: item['low_quality_flag'] == true,
          ),
        );
      }
    }

    return SessionClinicalReport(
      summary: summaryList.first,
      patientDisplayName: map['patient_display_name'] is String
          ? map['patient_display_name']! as String
          : 'Pengguna',
      classifierUsed: map['classifier_used'] is String
          ? map['classifier_used']! as String
          : 'LIGHTGBM_FFT',
      modelBundleVersion: map['model_bundle_version'] is String
          ? map['model_bundle_version']! as String
          : 'LightGBM+FFT v2026.11 (B_15hz)',
      thresholdUsed: _readDouble(map['threshold_used']) ?? 0.26,
      validLb6Ratio: _readDouble(map['valid_lb6_ratio']) ?? 1.0,
      totalFogDurationSec:
          _readDouble(map['total_fog_duration_sec']) ?? 0.0,
      medianEpisodeDurationSec:
          _readDouble(map['median_episode_duration_sec']) ?? 0.0,
      locomotorBandEnergy: _readDouble(map['locomotor_band_energy']) ?? 1.0,
      freezeBandEnergy: _readDouble(map['freeze_band_energy']) ?? 0.0,
      meanFreezeIndex: _readDouble(map['mean_freeze_index']) ?? 0.0,
      meanBilateralAsymmetry:
          _readDouble(map['mean_bilateral_asymmetry']) ?? 0.0,
      fallGuardFalseAlarms: _readInt(map['fall_guard_false_alarms']) ?? 0,
      videoSecurelyDeleted: map['video_securely_deleted'] != false,
      isSimulatedPreview: map['is_simulated_preview'] == true,
      recordedVideoPath: map['recorded_video_path'] is String &&
              (map['recorded_video_path']! as String).isNotEmpty
          ? map['recorded_video_path']! as String
          : null,
      poseTrackPath: map['pose_track_path'] is String &&
              (map['pose_track_path']! as String).isNotEmpty
          ? map['pose_track_path']! as String
          : null,
      episodes: List<FogEpisodeItem>.unmodifiable(episodes),
      windows: List<WindowPredictionItem>.unmodifiable(windows),
    );
  }

  Future<void> _persist(HomeDashboardSummary summary) async {
    try {
      final payload = <String, Object?>{
        'schema_version': 1,
        'dismissed_reminder_date_iso': summary.dismissedReminderDateIso,
        'recent_sessions': summary.recentSessions
            .map(
              (s) => <String, Object?>{
                'session_id': s.sessionId,
                'started_at_utc': s.startedAtUtc.toUtc().toIso8601String(),
                'protocol': s.protocol.storageValue,
                'med_state': s.medState.storageValue,
                'fog_percentage': s.fogPercentage,
                'episode_count': s.episodeCount,
                'duration_sec': s.durationSec,
                'sync_status': s.syncStatus.storageValue,
              },
            )
            .toList(),
        'medication_logs': summary.medicationLogs
            .map(
              (m) => <String, Object?>{
                'log_id': m.logId,
                'drug_name': m.drugName,
                'dosage_mg': m.dosageMg,
                'taken_at_utc': m.takenAtUtc.toUtc().toIso8601String(),
                'med_state': m.medState.storageValue,
                'notes': m.notes,
                'sync_status': m.syncStatus.storageValue,
              },
            )
            .toList(),
      };
      final ok = await _prefs.setString(storageKey, jsonEncode(payload));
      if (!ok) {
        throw const DashboardStorageFailure();
      }
    } catch (e) {
      if (e is DashboardFailure) rethrow;
      throw const DashboardStorageFailure();
    }
  }

  static List<SessionSummaryItem> _decodeSessions(Object? raw) {
    if (raw is! List<Object?>) return <SessionSummaryItem>[];
    final items = <SessionSummaryItem>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) continue;
      final id = entry['session_id'];
      final startedAt = _parseUtc(entry['started_at_utc']);
      final fogPct = _readDouble(entry['fog_percentage']);
      final durationSec = _readDouble(entry['duration_sec']);
      final episodeCount = _readInt(entry['episode_count']);
      if (id is! String ||
          id.isEmpty ||
          startedAt == null ||
          fogPct == null ||
          durationSec == null) {
        continue;
      }
      items.add(
        SessionSummaryItem(
          sessionId: id,
          startedAtUtc: startedAt,
          protocol: SessionProtocol.fromStorageValue(
            entry['protocol'] is String ? entry['protocol']! as String : null,
          ),
          medState: MedicationState.fromStorageValue(
            entry['med_state'] is String ? entry['med_state']! as String : null,
          ),
          fogPercentage: fogPct,
          episodeCount: episodeCount ?? 0,
          durationSec: durationSec,
          syncStatus: SessionSyncStatus.fromStorageValue(
            entry['sync_status'] is String
                ? entry['sync_status']! as String
                : null,
          ),
        ),
      );
    }
    return items;
  }

  static List<MedicationLog> _decodeMedicationLogs(Object? raw) {
    if (raw is! List<Object?>) return <MedicationLog>[];
    final items = <MedicationLog>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) continue;
      final id = entry['log_id'];
      final drugName = entry['drug_name'];
      final dosageMg = _readDouble(entry['dosage_mg']);
      final takenAt = _parseUtc(entry['taken_at_utc']);
      if (id is! String ||
          id.isEmpty ||
          drugName is! String ||
          drugName.isEmpty ||
          dosageMg == null ||
          takenAt == null) {
        continue;
      }
      final notesRaw = entry['notes'];
      items.add(
        MedicationLog(
          logId: id,
          drugName: drugName,
          dosageMg: dosageMg,
          takenAtUtc: takenAt,
          medState: MedicationState.fromStorageValue(
            entry['med_state'] is String ? entry['med_state']! as String : null,
          ),
          notes: notesRaw is String && notesRaw.isNotEmpty ? notesRaw : null,
          syncStatus: SessionSyncStatus.fromStorageValue(
            entry['sync_status'] is String
                ? entry['sync_status']! as String
                : null,
          ),
        ),
      );
    }
    return items;
  }

  static DateTime? _parseUtc(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static double? _readDouble(Object? raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return null;
  }

  static int? _readInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return null;
  }
}
