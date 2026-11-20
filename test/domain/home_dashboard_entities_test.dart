import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/entities/home_dashboard_summary.dart';
import 'package:parkinstep/domain/entities/medication_log.dart';
import 'package:parkinstep/domain/entities/session_summary_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_sync_status.dart';

void main() {
  group('Domain Enums & HomeDashboardSummary', () {
    test('MedicationState parses valid wire values and falls back to unknown', () {
      expect(MedicationState.fromStorageValue('ON'), MedicationState.on);
      expect(MedicationState.fromStorageValue('OFF'), MedicationState.off);
      expect(
        MedicationState.fromStorageValue('UNKNOWN'),
        MedicationState.unknown,
      );
      expect(
        MedicationState.fromStorageValue('INVALID'),
        MedicationState.unknown,
      );
      expect(MedicationState.fromStorageValue(null), MedicationState.unknown);
    });

    test('SessionSyncStatus parses valid wire values and falls back cleanly', () {
      expect(
        SessionSyncStatus.fromStorageValue('LOCAL_ONLY'),
        SessionSyncStatus.localOnly,
      );
      expect(
        SessionSyncStatus.fromStorageValue('PENDING'),
        SessionSyncStatus.pending,
      );
      expect(
        SessionSyncStatus.fromStorageValue('SYNCED'),
        SessionSyncStatus.synced,
      );
      expect(
        SessionSyncStatus.fromStorageValue(null),
        SessionSyncStatus.localOnly,
      );
    });

    test('HomeDashboardSummary exposes latest session, latest log, reminder & value equality', () {
      final t1 = DateTime.utc(2026, 11, 20, 8, 0);
      final t2 = DateTime.utc(2026, 11, 19, 8, 0);

      final s1 = SessionSummaryItem(
        sessionId: 'sess-1',
        startedAtUtc: t1,
        medState: MedicationState.on,
        fogPercentage: 2.4,
        episodeCount: 1,
        durationSec: 120.0,
      );
      final s2 = SessionSummaryItem(
        sessionId: 'sess-2',
        startedAtUtc: t2,
        medState: MedicationState.off,
        fogPercentage: 14.2,
        episodeCount: 3,
        durationSec: 120.0,
      );
      final m1 = MedicationLog(
        logId: 'med-1',
        drugName: 'Levodopa',
        dosageMg: 100,
        takenAtUtc: t1,
        medState: MedicationState.on,
      );

      final summaryA = HomeDashboardSummary(
        recentSessions: <SessionSummaryItem>[s1, s2],
        medicationLogs: <MedicationLog>[m1],
        dismissedReminderDateIso: '2026-11-20',
      );
      final summaryB = HomeDashboardSummary(
        recentSessions: <SessionSummaryItem>[s1, s2],
        medicationLogs: <MedicationLog>[m1],
        dismissedReminderDateIso: '2026-11-20',
      );

      expect(summaryA.latestSession, s1);
      expect(summaryA.latestMedicationLog, m1);
      expect(summaryA.hasRealSessions, isTrue);
      expect(summaryA.isReminderDismissedOn('2026-11-20'), isTrue);
      expect(summaryA.isReminderDismissedOn('2026-11-21'), isFalse);
      expect(summaryA, equals(summaryB));
      expect(summaryA.hashCode, equals(summaryB.hashCode));

      const emptySummary = HomeDashboardSummary();
      expect(emptySummary.latestSession, isNull);
      expect(emptySummary.latestMedicationLog, isNull);
      expect(emptySummary.hasRealSessions, isFalse);
    });
  });
}
