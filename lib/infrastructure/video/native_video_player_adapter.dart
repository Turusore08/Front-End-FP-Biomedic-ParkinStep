import 'package:flutter/services.dart';

import '../../application/ports/video_playback_port.dart';

class _SimPlayerState {
  _SimPlayerState({
    required this.playerId,
    required this.durationMs,
    required this.width,
    required this.height,
  });

  final String playerId;
  final int durationMs;
  final double width;
  final double height;
  int positionMs = 0;
  bool isPlaying = false;
  bool isCompleted = false;
  DateTime? lastPolledAt;
}

/// Texture video playback adapter backed by Android `MediaPlayer` + `SurfaceProducer`,
/// with a built-in deterministic simulated player for `preview://` & widget tests.
class NativeVideoPlayerAdapter implements VideoPlaybackPort {
  NativeVideoPlayerAdapter({
    MethodChannel? channel,
    DateTime Function()? clock,
  })  : _channel = channel ??
            const MethodChannel('id.parkinstep.parkinstep/video_player'),
        _clock = clock ?? DateTime.now;

  final MethodChannel _channel;
  final DateTime Function() _clock;
  final Map<String, _SimPlayerState> _simPlayers = <String, _SimPlayerState>{};
  int _simSeq = 0;

  @override
  Future<OpenedVideoPlayback> open(
    String videoPath, {
    required int fallbackDurationMs,
    required double fallbackWidth,
    required double fallbackHeight,
  }) async {
    if (videoPath.startsWith('preview://')) {
      return _openSimulated(
        durationMs: fallbackDurationMs,
        width: fallbackWidth,
        height: fallbackHeight,
      );
    }

    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'open',
        <String, Object?>{'path': videoPath},
      );
      if (raw == null) {
        throw StateError('Video player gagal dibuka.');
      }
      return OpenedVideoPlayback(
        playerId: raw['playerId']! as String,
        textureId: (raw['textureId'] as num?)?.toInt(),
        uprightWidth: (raw['uprightWidth'] as num?)?.toDouble() ?? fallbackWidth,
        uprightHeight:
            (raw['uprightHeight'] as num?)?.toDouble() ?? fallbackHeight,
        durationMs: (raw['durationMs'] as num?)?.toInt() ?? fallbackDurationMs,
        rotationDegrees: (raw['rotationDegrees'] as num?)?.toInt() ?? 0,
        handlesCropAndRotation: raw['handlesCropAndRotation'] == true,
      );
    } on MissingPluginException {
      return _openSimulated(
        durationMs: fallbackDurationMs,
        width: fallbackWidth,
        height: fallbackHeight,
      );
    }
  }

  OpenedVideoPlayback _openSimulated({
    required int durationMs,
    required double width,
    required double height,
  }) {
    _simSeq++;
    final id = 'sim_player_$_simSeq';
    final safeDur = durationMs > 0 ? durationMs : 4000;
    final safeW = width > 0 ? width : 480.0;
    final safeH = height > 0 ? height : 640.0;
    _simPlayers[id] = _SimPlayerState(
      playerId: id,
      durationMs: safeDur,
      width: safeW,
      height: safeH,
    );
    return OpenedVideoPlayback(
      playerId: id,
      textureId: null,
      uprightWidth: safeW,
      uprightHeight: safeH,
      durationMs: safeDur,
      rotationDegrees: 0,
      handlesCropAndRotation: true,
      isSimulated: true,
    );
  }

  @override
  Future<void> play(String playerId) async {
    final sim = _simPlayers[playerId];
    if (sim != null) {
      if (sim.isCompleted || sim.positionMs >= sim.durationMs) {
        sim.positionMs = 0;
        sim.isCompleted = false;
      }
      sim.isPlaying = true;
      sim.lastPolledAt = _clock();
      return;
    }
    await _channel.invokeMethod<void>('play', <String, Object?>{'playerId': playerId});
  }

  @override
  Future<void> pause(String playerId) async {
    final sim = _simPlayers[playerId];
    if (sim != null) {
      _advanceSimulated(sim);
      sim.isPlaying = false;
      sim.lastPolledAt = null;
      return;
    }
    await _channel.invokeMethod<void>('pause', <String, Object?>{'playerId': playerId});
  }

  @override
  Future<void> seekTo(String playerId, int positionMs) async {
    final sim = _simPlayers[playerId];
    if (sim != null) {
      sim.positionMs = positionMs.clamp(0, sim.durationMs);
      sim.isCompleted = sim.positionMs >= sim.durationMs;
      sim.lastPolledAt = sim.isPlaying ? _clock() : null;
      return;
    }
    await _channel.invokeMethod<void>(
      'seekTo',
      <String, Object?>{'playerId': playerId, 'positionMs': positionMs},
    );
  }

  @override
  Future<VideoPlaybackSnapshot> getPosition(String playerId) async {
    final sim = _simPlayers[playerId];
    if (sim != null) {
      _advanceSimulated(sim);
      return VideoPlaybackSnapshot(
        positionMs: sim.positionMs,
        durationMs: sim.durationMs,
        isPlaying: sim.isPlaying,
        isCompleted: sim.isCompleted,
      );
    }
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getPosition',
      <String, Object?>{'playerId': playerId},
    );
    return VideoPlaybackSnapshot(
      positionMs: (raw?['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (raw?['durationMs'] as num?)?.toInt() ?? 0,
      isPlaying: raw?['isPlaying'] == true,
      isCompleted: raw?['isCompleted'] == true,
    );
  }

  void _advanceSimulated(_SimPlayerState sim) {
    if (!sim.isPlaying) return;
    final now = _clock();
    final elapsedReal = sim.lastPolledAt == null
        ? 0
        : now.difference(sim.lastPolledAt!).inMilliseconds;
    sim.lastPolledAt = now;
    final stepMs = elapsedReal >= 25 ? elapsedReal : 66;
    sim.positionMs = (sim.positionMs + stepMs).clamp(0, sim.durationMs);
    if (sim.positionMs >= sim.durationMs) {
      sim.isPlaying = false;
      sim.isCompleted = true;
    }
  }

  @override
  Future<void> dispose(String playerId) async {
    if (_simPlayers.remove(playerId) != null) return;
    try {
      await _channel.invokeMethod<void>(
        'dispose',
        <String, Object?>{'playerId': playerId},
      );
    } catch (_) {}
  }
}
