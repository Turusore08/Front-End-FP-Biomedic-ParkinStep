import '../../domain/entities/home_dashboard_summary.dart';
import '../ports/home_dashboard_repository_port.dart';

/// Loads offline-first S-03 dashboard summary from local storage.
class LoadHomeDashboard {
  const LoadHomeDashboard(this._repository);

  final HomeDashboardRepositoryPort _repository;

  Future<HomeDashboardSummary> execute() => _repository.loadSummary();
}
