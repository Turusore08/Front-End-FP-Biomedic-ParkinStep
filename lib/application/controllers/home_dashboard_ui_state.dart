import '../../domain/entities/home_dashboard_summary.dart';

/// Immutable UI snapshot for S-03 Home Dashboard and Riwayat summary views.
class HomeDashboardUiState {
  const HomeDashboardUiState({
    this.isInitialized = false,
    this.isBusy = false,
    this.summary = const HomeDashboardSummary(),
    this.errorMessage,
  });

  final bool isInitialized;
  final bool isBusy;
  final HomeDashboardSummary summary;
  final String? errorMessage;

  HomeDashboardUiState copyWith({
    bool? isInitialized,
    bool? isBusy,
    HomeDashboardSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeDashboardUiState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBusy: isBusy ?? this.isBusy,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
