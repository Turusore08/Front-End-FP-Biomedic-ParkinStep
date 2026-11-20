import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/application/use_cases/dismiss_daily_reminder.dart';
import 'package:parkinstep/application/use_cases/load_home_dashboard.dart';
import 'package:parkinstep/application/use_cases/log_medication_intake.dart';
import 'package:parkinstep/domain/entities/session_summary_item.dart';
import 'package:parkinstep/domain/enums/medication_state.dart';
import 'package:parkinstep/domain/enums/session_sync_status.dart';
import 'package:parkinstep/domain/errors/dashboard_failure.dart';
import 'package:parkinstep/infrastructure/persistence/local_home_dashboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Dashboard Use Cases & LocalHomeDashboardRepository', () {
    test('LogMedicationIntake validates drug name & dosage bounds before persisting', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalHomeDashboardRepository(prefs);
      final fixedUtc = DateTime.utc(2026, 11, 20, 9, 30);
      final useCase = LogMedicationIntake(repo, clock: () => fixedUtc);

      await expectLater(
        () => useCase.execute(
          drugName: '   ',
          dosageMg: 100,
          medState: MedicationState.on,
        ),
        throwsA(isA<InvalidDrugNameFailure>()),
      );

      await expectLater(
        () => useCase.execute(
          drugName: 'A' * 81,
          dosageMg: 100,
          medState: MedicationState.on,
        ),
        throwsA(isA<InvalidDrugNameFailure>()),
      );

      await expectLater(
        () => useCase.execute(
          drugName: 'Levodopa',
          dosageMg: 0,
          medState: MedicationState.off,
        ),
        throwsA(isA<InvalidDosageFailure>()),
      );

      await expectLater(
        () => useCase.execute(
          drugName: 'Levodopa',
          dosageMg: 2500,
          medState: MedicationState.off,
        ),
        throwsA(isA<InvalidDosageFailure>()),
      );

      final updated = await useCase.execute(
        drugName: '  Levodopa / Carbidopa  ',
        dosageMg: 150,
        medState: MedicationState.on,
        notes: '  Sesudah sarapan  ',
      );

      expect(updated.medicationLogs, hasLength(1));
      final saved = updated.medicationLogs.first;
      expect(saved.drugName, 'Levodopa / Carbidopa');
      expect(saved.dosageMg, 150.0);
      expect(saved.medState, MedicationState.on);
      expect(saved.notes, 'Sesudah sarapan');
      expect(saved.takenAtUtc, fixedUtc);
    });

    test('DismissDailyReminder stores formatted local date and repository round-trips', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalHomeDashboardRepository(prefs);
      final fakeLocalClock = DateTime(2026, 11, 20, 7, 15);

      await repo.saveSessionSummary(
        SessionSummaryItem(
          sessionId: 'sess-older',
          startedAtUtc: DateTime.utc(2026, 11, 18, 7, 0),
          medState: MedicationState.off,
          fogPercentage: 12.6,
          episodeCount: 2,
          durationSec: 120.0,
        ),
      );
      await repo.saveSessionSummary(
        SessionSummaryItem(
          sessionId: 'sess-newest',
          startedAtUtc: DateTime.utc(2026, 11, 20, 7, 0),
          medState: MedicationState.on,
          fogPercentage: 2.4,
          episodeCount: 0,
          durationSec: 120.0,
          syncStatus: SessionSyncStatus.synced,
        ),
      );

      final dismissUseCase = DismissDailyReminder(
        repo,
        clock: () => fakeLocalClock,
      );
      await dismissUseCase.execute();

      final loaded = await LoadHomeDashboard(repo).execute();
      expect(loaded.dismissedReminderDateIso, '2026-11-20');
      expect(loaded.isReminderDismissedOn('2026-11-20'), isTrue);
      expect(loaded.recentSessions, hasLength(2));
      expect(loaded.recentSessions.first.sessionId, 'sess-newest');
      expect(loaded.latestSession?.fogPercentage, 2.4);
      expect(loaded.latestSession?.syncStatus, SessionSyncStatus.synced);
    });

    test('LocalHomeDashboardRepository handles corrupt JSON gracefully without crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalHomeDashboardRepository.storageKey: '{not valid json!!!',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalHomeDashboardRepository(prefs);

      final summary = await repo.loadSummary();
      expect(summary.recentSessions, isEmpty);
      expect(summary.medicationLogs, isEmpty);
      expect(summary.dismissedReminderDateIso, isNull);
    });
  });
}
