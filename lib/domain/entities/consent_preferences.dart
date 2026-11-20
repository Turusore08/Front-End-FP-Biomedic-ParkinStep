/// Granular UU PDP No. 27/2022 consent toggles managed in S-02.
class ConsentPreferences {
  const ConsentPreferences({
    this.consentLocal = true,
    this.consentSkeletonSync = false,
    this.consentCloudVideo = false,
    this.acceptedAtUtc,
  });

  /// Mandatory on-device camera processing permission (zero raw-video retention).
  final bool consentLocal;

  /// Optional anonymous LB6 joint coordinate & session summary cloud sync.
  final bool consentSkeletonSync;

  /// Optional fallback video upload audit permission (default OFF).
  final bool consentCloudVideo;

  /// Always stored as UTC timestamp when submitted.
  final DateTime? acceptedAtUtc;

  /// User may only proceed when mandatory local processing consent is enabled.
  bool get canProceed => consentLocal;

  ConsentPreferences copyWith({
    bool? consentLocal,
    bool? consentSkeletonSync,
    bool? consentCloudVideo,
    DateTime? acceptedAtUtc,
    bool clearAcceptedAt = false,
  }) {
    return ConsentPreferences(
      consentLocal: consentLocal ?? this.consentLocal,
      consentSkeletonSync: consentSkeletonSync ?? this.consentSkeletonSync,
      consentCloudVideo: consentCloudVideo ?? this.consentCloudVideo,
      acceptedAtUtc:
          clearAcceptedAt ? null : (acceptedAtUtc ?? this.acceptedAtUtc),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsentPreferences &&
        other.consentLocal == consentLocal &&
        other.consentSkeletonSync == consentSkeletonSync &&
        other.consentCloudVideo == consentCloudVideo &&
        other.acceptedAtUtc == acceptedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
        consentLocal,
        consentSkeletonSync,
        consentCloudVideo,
        acceptedAtUtc,
      );
}
