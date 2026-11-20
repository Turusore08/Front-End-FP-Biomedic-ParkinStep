/// Sync lifecycle state for offline-first clinical summaries and medication logs.
enum SessionSyncStatus {
  localOnly('LOCAL_ONLY', 'Tersimpan Lokal'),
  pending('PENDING', 'Menunggu Sinkronisasi'),
  synced('SYNCED', 'Tersinkron ke Dokter');

  const SessionSyncStatus(this.storageValue, this.labelId);

  final String storageValue;
  final String labelId;

  static SessionSyncStatus fromStorageValue(String? raw) {
    for (final status in SessionSyncStatus.values) {
      if (status.storageValue == raw) return status;
    }
    return SessionSyncStatus.localOnly;
  }
}
