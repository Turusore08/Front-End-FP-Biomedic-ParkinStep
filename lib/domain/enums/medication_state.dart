/// Levodopa medication status logged by the patient or caregiver.
enum MedicationState {
  on('ON', 'ON Obat', 'Obat sedang bekerja'),
  off('OFF', 'OFF Obat', 'Efek obat menurun'),
  unknown('UNKNOWN', 'Tidak Tahu', 'Belum pasti');

  const MedicationState(this.storageValue, this.labelId, this.descriptionId);

  final String storageValue;
  final String labelId;
  final String descriptionId;

  static MedicationState fromStorageValue(String? raw) {
    for (final state in MedicationState.values) {
      if (state.storageValue == raw) return state;
    }
    return MedicationState.unknown;
  }
}
