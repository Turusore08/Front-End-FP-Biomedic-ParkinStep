/// Domain-level failures surfaced while managing S-03 dashboard & medication logs.
sealed class DashboardFailure implements Exception {
  const DashboardFailure(this.message);

  /// Elderly-friendly Indonesian explanation shown with a warning icon.
  final String message;
}

final class InvalidDrugNameFailure extends DashboardFailure {
  const InvalidDrugNameFailure()
      : super('Masukkan nama obat antara 1 hingga 80 karakter.');
}

final class InvalidDosageFailure extends DashboardFailure {
  const InvalidDosageFailure()
      : super('Masukkan dosis obat yang valid antara 1 hingga 2000 mg.');
}

final class DashboardStorageFailure extends DashboardFailure {
  const DashboardStorageFailure()
      : super('Gagal menyimpan data lokal ke memori perangkat. Silakan coba lagi.');
}
