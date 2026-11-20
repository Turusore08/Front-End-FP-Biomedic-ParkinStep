import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/controllers/home_dashboard_coordinator.dart';
import '../application/controllers/home_dashboard_ui_state.dart';
import '../application/ports/home_dashboard_repository_port.dart';
import '../domain/enums/medication_state.dart';
import '../infrastructure/persistence/local_home_dashboard_repository.dart';
import 'onboarding_providers.dart';

final homeDashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepositoryPort>(
  (ref) => LocalHomeDashboardRepository(ref.watch(sharedPreferencesProvider)),
);

/// Riverpod 3 Notifier binding pure-Dart HomeDashboardCoordinator to Flutter UI.
class HomeDashboardController extends Notifier<HomeDashboardUiState> {
  late HomeDashboardCoordinator _coordinator;

  @override
  HomeDashboardUiState build() {
    _coordinator = HomeDashboardCoordinator(
      repository: ref.read(homeDashboardRepositoryProvider),
      clock: ref.read(homeDashboardClockProvider),
      readState: () => state,
      writeState: (next) => state = next,
    );

    Future<void>.microtask(_coordinator.initialize);
    return const HomeDashboardUiState();
  }

  String get todayLocalDateIso => _coordinator.todayLocalDateIso;

  Future<void> initialize() => _coordinator.initialize();

  Future<String?> logMedicationIntake({
    required String drugName,
    required double dosageMg,
    required MedicationState medState,
    String? notes,
  }) =>
      _coordinator.logMedicationIntake(
        drugName: drugName,
        dosageMg: dosageMg,
        medState: medState,
        notes: notes,
      );

  Future<void> dismissDailyReminder() => _coordinator.dismissDailyReminder();

  Future<void> clearAll() => _coordinator.clearAll();
}

final homeDashboardControllerProvider =
    NotifierProvider<HomeDashboardController, HomeDashboardUiState>(
  HomeDashboardController.new,
);
