import '../enums/medication_state.dart';
import '../enums/session_protocol.dart';
import '../enums/session_sync_status.dart';

/// Summary of a completed gait screening session shown in S-03 metric pill & carousel.
class SessionSummaryItem {
  const SessionSummaryItem({
    required this.sessionId,
    required this.startedAtUtc,
    this.protocol = SessionProtocol.turning360,
    required this.medState,
    required this.fogPercentage,
    required this.episodeCount,
    required this.durationSec,
    this.syncStatus = SessionSyncStatus.localOnly,
  });

  final String sessionId;
  final DateTime startedAtUtc;
  final SessionProtocol protocol;
  final MedicationState medState;
  final double fogPercentage;
  final int episodeCount;
  final double durationSec;
  final SessionSyncStatus syncStatus;

  SessionSummaryItem copyWith({
    String? sessionId,
    DateTime? startedAtUtc,
    SessionProtocol? protocol,
    MedicationState? medState,
    double? fogPercentage,
    int? episodeCount,
    double? durationSec,
    SessionSyncStatus? syncStatus,
  }) {
    return SessionSummaryItem(
      sessionId: sessionId ?? this.sessionId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      protocol: protocol ?? this.protocol,
      medState: medState ?? this.medState,
      fogPercentage: fogPercentage ?? this.fogPercentage,
      episodeCount: episodeCount ?? this.episodeCount,
      durationSec: durationSec ?? this.durationSec,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionSummaryItem &&
        other.sessionId == sessionId &&
        other.startedAtUtc == startedAtUtc &&
        other.protocol == protocol &&
        other.medState == medState &&
        other.fogPercentage == fogPercentage &&
        other.episodeCount == episodeCount &&
        other.durationSec == durationSec &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        sessionId,
        startedAtUtc,
        protocol,
        medState,
        fogPercentage,
        episodeCount,
        durationSec,
        syncStatus,
      );
}
