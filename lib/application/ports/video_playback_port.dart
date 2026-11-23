/// Metadata returned when opening a recorded local MP4 for texture playback.
class OpenedVideoPlayback {
  const OpenedVideoPlayback({
    required this.playerId,
    required this.textureId,
    required this.uprightWidth,
    required this.uprightHeight,
    required this.durationMs,
    required this.rotationDegrees,
    required this.handlesCropAndRotation,
    this.isSimulated = false,
  });

  final String playerId;
  final int? textureId;
  final double uprightWidth;
  final double uprightHeight;
  final int durationMs;
  final int rotationDegrees;
  final bool handlesCropAndRotation;
  final bool isSimulated;
}

/// Snapshot of current playback clock and transport state.
class VideoPlaybackSnapshot {
  const VideoPlaybackSnapshot({
    required this.positionMs,
    required this.durationMs,
    required this.isPlaying,
    required this.isCompleted,
  });

  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final bool isCompleted;
}

/// Pure Dart port abstracting local recorded MP4 texture playback for synchronized
/// post-session skeleton inspection without embedding platform dependencies.
abstract interface class VideoPlaybackPort {
  Future<OpenedVideoPlayback> open(
    String videoPath, {
    required int fallbackDurationMs,
    required double fallbackWidth,
    required double fallbackHeight,
  });

  Future<void> play(String playerId);

  Future<void> pause(String playerId);

  Future<void> seekTo(String playerId, int positionMs);

  Future<VideoPlaybackSnapshot> getPosition(String playerId);

  Future<void> dispose(String playerId);
}
