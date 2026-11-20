import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/home_dashboard_repository_port.dart';
import '../../domain/entities/home_dashboard_summary.dart';
import '../../domain/entities/medication_log.dart';
import '../../domain/entities/session_summary_item.dart';
import '../../domain/enums/medication_state.dart';
import '../../domain/enums/session_sync_status.dart';
import '../../domain/errors/dashboard_failure.dart';

/// Offline-first SharedPreferences adapter for S-03 dashboard state,
/// recent sessions, medication logs, and reminder dismissals.
class LocalHomeDashboardRepository implements HomeDashboardRepositoryPort {
  const LocalHomeDashboardRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'parkinstep_dashboard_v1';
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
