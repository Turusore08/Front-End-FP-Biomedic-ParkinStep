import '../value_objects/keypoint_2d.dart';

/// Single extracted 17-COCO pose frame paired with its video playback timestamp.
class TimedPoseFrame {
  const TimedPoseFrame({
    required this.timestampMs,
    required this.keypoints17,
  });

  final int timestampMs;
  final List<Keypoint2D> keypoints17;

  Map<String, Object?> toJsonMap() {
    final flat = <double>[];
    for (var i = 0; i < keypoints17.length; i++) {
      final kp = keypoints17[i];
      flat.add(double.parse(kp.x.toStringAsFixed(1)));
      flat.add(double.parse(kp.y.toStringAsFixed(1)));
      flat.add(double.parse(kp.conf.toStringAsFixed(3)));
    }
    return <String, Object?>{
      't': timestampMs,
      'k': flat,
    };
  }

  static TimedPoseFrame? fromJsonMap(Map<String, Object?> map) {
    final tRaw = map['t'];
    final kRaw = map['k'];
    if (tRaw is! num || kRaw is! List<Object?>) return null;
    if (kRaw.length < 51) return null;

    final keypoints = <Keypoint2D>[];
    for (var i = 0; i < 17; i++) {
      final base = i * 3;
      final x = kRaw[base];
      final y = kRaw[base + 1];
      final c = kRaw[base + 2];
      if (x is! num || y is! num || c is! num) return null;
      keypoints.add(
        Keypoint2D(
          x: x.toDouble(),
          y: y.toDouble(),
          conf: c.toDouble().clamp(0.0, 1.0),
        ),
      );
    }

    return TimedPoseFrame(
      timestampMs: tRaw.toInt(),
      keypoints17: List<Keypoint2D>.unmodifiable(keypoints),
    );
  }
}

/// Extracted 15 Hz 17-COCO skeleton sequence synchronized to a locally recorded video.
class RecordedPoseTrack {
  const RecordedPoseTrack({
    required this.imageWidth,
    required this.imageHeight,
    required this.durationMs,
    required this.frames,
  });

  final double imageWidth;
  final double imageHeight;
  final int durationMs;
  final List<TimedPoseFrame> frames;

  /// Binary-searches the nearest frame in [frames] for playback timestamp [positionMs].
  TimedPoseFrame? frameAtMs(int positionMs) {
    if (frames.isEmpty) return null;
    if (positionMs <= frames.first.timestampMs) return frames.first;
    if (positionMs >= frames.last.timestampMs) return frames.last;

    var low = 0;
    var high = frames.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final t = frames[mid].timestampMs;
      if (t == positionMs) {
        return frames[mid];
      } else if (t < positionMs) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (low >= frames.length) return frames.last;
    if (high < 0) return frames.first;
    final diffLow = (frames[low].timestampMs - positionMs).abs();
    final diffHigh = (positionMs - frames[high].timestampMs).abs();
    return diffLow < diffHigh ? frames[low] : frames[high];
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'w': double.parse(imageWidth.toStringAsFixed(1)),
      'h': double.parse(imageHeight.toStringAsFixed(1)),
      'd': durationMs,
      'frames': frames.map((f) => f.toJsonMap()).toList(),
    };
  }

  static RecordedPoseTrack? fromJsonMap(Map<String, Object?> map) {
    final wRaw = map['w'];
    final hRaw = map['h'];
    final dRaw = map['d'];
    final framesRaw = map['frames'];
    if (wRaw is! num || hRaw is! num || framesRaw is! List<Object?>) {
      return null;
    }

    final parsedFrames = <TimedPoseFrame>[];
    for (final item in framesRaw) {
      if (item is! Map<String, Object?>) continue;
      final parsed = TimedPoseFrame.fromJsonMap(item);
      if (parsed != null) {
        parsedFrames.add(parsed);
      }
    }

    parsedFrames.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final fallbackDuration = parsedFrames.isEmpty
        ? 0
        : parsedFrames.last.timestampMs;

    return RecordedPoseTrack(
      imageWidth: wRaw.toDouble(),
      imageHeight: hRaw.toDouble(),
      durationMs: dRaw is num ? dRaw.toInt() : fallbackDuration,
      frames: List<TimedPoseFrame>.unmodifiable(parsedFrames),
    );
  }
}
