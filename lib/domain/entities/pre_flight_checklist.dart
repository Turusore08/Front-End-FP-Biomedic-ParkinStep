import '../enums/medication_state.dart';
import '../enums/session_protocol.dart';

/// Immutable pre-flight safety, protocol selection & Levodopa state required before camera launch.
class PreFlightChecklist {
  const PreFlightChecklist({
    this.protocol = SessionProtocol.turning360,
    this.floorSafe = false,
    this.spaceClear = false,
    this.supportReady = false,
    this.attireAndFraming = false,
    this.medState = MedicationState.unknown,
  });

  final SessionProtocol protocol;
  final bool floorSafe;
  final bool spaceClear;
  final bool supportReady;
  final bool attireAndFraming;
  final MedicationState medState;

  int get completedCount =>
      (floorSafe ? 1 : 0) +
      (spaceClear ? 1 : 0) +
      (supportReady ? 1 : 0) +
      (attireAndFraming ? 1 : 0);

  bool get isAllChecked => completedCount == 4;

  PreFlightChecklist copyWith({
    SessionProtocol? protocol,
    bool? floorSafe,
    bool? spaceClear,
    bool? supportReady,
    bool? attireAndFraming,
    MedicationState? medState,
  }) {
    return PreFlightChecklist(
      protocol: protocol ?? this.protocol,
      floorSafe: floorSafe ?? this.floorSafe,
      spaceClear: spaceClear ?? this.spaceClear,
      supportReady: supportReady ?? this.supportReady,
      attireAndFraming: attireAndFraming ?? this.attireAndFraming,
      medState: medState ?? this.medState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreFlightChecklist &&
        other.protocol == protocol &&
        other.floorSafe == floorSafe &&
        other.spaceClear == spaceClear &&
        other.supportReady == supportReady &&
        other.attireAndFraming == attireAndFraming &&
        other.medState == medState;
  }

  @override
  int get hashCode => Object.hash(
        protocol,
        floorSafe,
        spaceClear,
        supportReady,
        attireAndFraming,
        medState,
      );
}
