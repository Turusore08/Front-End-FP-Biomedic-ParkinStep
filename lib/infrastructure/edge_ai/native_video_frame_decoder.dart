import 'package:flutter/services.dart';

import 'yolo_pose_codec.dart';

/// Metadata returned when opening a recorded `.mp4` file natively.
class OpenedVideoInfo {
  const OpenedVideoInfo({
    required this.decoderId,
    required this.durationMs,
    required this.estimatedFrames,
    required this.rotationDegrees,
  });

  final String decoderId;
  final int durationMs;
  final int estimatedFrames;
  final int rotationDegrees;
}

/// Decoded video frame paired with its native presentation timestamp.
class DecodedVideoFrame {
  const DecodedVideoFrame({
    required this.frame,
    required this.timestampMs,
  });

  final YuvFrame frame;
  final int timestampMs;
}

/// Pull-based bridge to Android `VideoFrameExtractor` decoding 15 Hz YUV420 frames.
class NativeVideoFrameDecoder {
  NativeVideoFrameDecoder({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('id.parkinstep.parkinstep/video_decoder');

  final MethodChannel _channel;
  String? _decoderId;

  Future<OpenedVideoInfo> open(
    String path, {
    double targetFps = 15.0,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'openVideo',
      <String, Object?>{
        'path': path,
        'targetFps': targetFps,
      },
    );
    if (raw == null) {
      throw StateError('Decoder failed to open video.');
    }
    final decoderId = raw['decoderId'] as String?;
    if (decoderId == null || decoderId.isEmpty) {
      throw StateError('Decoder returned an empty session ID.');
    }
    _decoderId = decoderId;
    return OpenedVideoInfo(
      decoderId: decoderId,
      durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
      estimatedFrames: ((raw['estimatedFrames'] as num?)?.toInt() ?? 1)
          .clamp(1, 100000),
      rotationDegrees: (raw['rotationDegrees'] as num?)?.toInt() ?? 0,
    );
  }

  Future<DecodedVideoFrame?> nextFrame() async {
    final decoderId = _decoderId;
    if (decoderId == null) return null;
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'nextFrame',
      <String, Object?>{'decoderId': decoderId},
    );
    if (raw == null) return null;

    final frame = YuvFrame(
      width: (raw['width'] as num).toInt(),
      height: (raw['height'] as num).toInt(),
      yBytes: raw['yBytes']! as Uint8List,
      uBytes: raw['uBytes']! as Uint8List,
      vBytes: raw['vBytes']! as Uint8List,
      yRowStride: (raw['yRowStride'] as num).toInt(),
      uvRowStride: (raw['uvRowStride'] as num).toInt(),
      uvPixelStride: (raw['uvPixelStride'] as num).toInt(),
      rotationDegrees: (raw['rotationDegrees'] as num).toInt(),
    );
    return DecodedVideoFrame(
      frame: frame,
      timestampMs: (raw['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> close() async {
    final decoderId = _decoderId;
    _decoderId = null;
    if (decoderId == null) return;
    try {
      await _channel.invokeMethod<void>(
        'closeVideo',
        <String, Object?>{'decoderId': decoderId},
      );
    } catch (_) {
      // Ignore cleanup errors during cancellation/disposal.
    }
  }
}
