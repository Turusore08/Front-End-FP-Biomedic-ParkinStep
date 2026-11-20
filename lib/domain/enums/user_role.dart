/// Primary user role operating the ParkinStep mobile application.
enum UserRole {
  patient('PATIENT', 'Pasien'),
  caregiver('CAREGIVER', 'Caregiver / Pendamping'),
  clinician('CLINICIAN', 'Dokter / Klinisi');

  const UserRole(this.wireValue, this.labelId);

  /// Stable string enum matching API_CONTRACT.md & SQLite DDL.
  final String wireValue;

  /// Accessible Indonesian display label.
  final String labelId;

  static UserRole fromWire(String? value) {
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    return UserRole.patient;
  }
}
