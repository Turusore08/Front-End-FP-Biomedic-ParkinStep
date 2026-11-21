import 'dart:typed_data';

import '../../domain/value_objects/keypoint_2d.dart';

/// Raw YUV_420_888 camera frame copied out of the platform buffer so it can be
/// sent to a background isolate for letterbox preprocessing.
class YuvFrame {
  const YuvFrame({
    required this.width,
    required this.height,
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  /// Clockwise rotation (0/90/180/270) turning the sensor buffer upright.
  final int rotationDegrees;

  bool get _isQuarterTurn => rotationDegrees == 90 || rotationDegrees == 270;

  /// Upright image width after applying [rotationDegrees].
  int get uprightWidth => _isQuarterTurn ? height : width;

  /// Upright image height after applying [rotationDegrees].
  int get uprightHeight => _isQuarterTurn ? width : height;
}

/// Letterbox geometry mapping model-space (640x640) pixels back to the upright image.
class LetterboxMeta {
  const LetterboxMeta({
    required this.scale,
    required this.padLeft,
    required this.padTop,
    required this.imageWidth,
    required this.imageHeight,
  });

  final double scale;
  final int padLeft;
  final int padTop;
  final int imageWidth;
  final int imageHeight;
}

/// NCHW float32 tensor plus the letterbox geometry used to build it.
class YoloInput {
  const YoloInput({required this.tensor, required this.meta});

  final Float32List tensor;
  final LetterboxMeta meta;
}

/// Pre/post-processing contract for `yolo26n-pose.onnx`:
/// input `images` [1,3,640,640] RGB 0..1 letterboxed (pad 114, auto=False),
/// output `output0` [1,56,8400] = cx,cy,w,h, conf, 17 x (x,y,conf) in model pixels.
abstract final class YoloPoseCodec {
  static const int inputSize = 640;
  static const int anchors = 8400;
  static const int channels = 56;
  static const int keypointCount = 17;
  static const double detConf = 0.25;
  static const double _padValue = 114 / 255;

  /// Builds the letterbox geometry Ultralytics uses for `LetterBox(auto=False)`.
  static LetterboxMeta letterboxFor(int imageWidth, int imageHeight) {
    final scale = _min(inputSize / imageWidth, inputSize / imageHeight);
    final newW = (imageWidth * scale).round();
    final newH = (imageHeight * scale).round();
    return LetterboxMeta(
      scale: scale,
      padLeft: ((inputSize - newW) / 2 - 0.1).round(),
      padTop: ((inputSize - newH) / 2 - 0.1).round(),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Converts a YUV frame into the rotated, letterboxed NCHW RGB tensor.
  /// Uses nearest-neighbour sampling (Ultralytics uses bilinear resize).
  static YoloInput preprocess(YuvFrame frame) {
    final meta = letterboxFor(frame.uprightWidth, frame.uprightHeight);
    const plane = inputSize * inputSize;
    final tensor = Float32List(3 * plane)..fillRange(0, 3 * plane, _padValue);

    final newW = (meta.imageWidth * meta.scale).round();
    final newH = (meta.imageHeight * meta.scale).round();
    final maxX = meta.imageWidth - 1;
    final maxY = meta.imageHeight - 1;

    for (var oy = 0; oy < newH; oy++) {
      final ry = _clamp(((oy + 0.5) / meta.scale).floor(), maxY);
      final rowBase = (oy + meta.padTop) * inputSize + meta.padLeft;
      for (var ox = 0; ox < newW; ox++) {
        final rx = _clamp(((ox + 0.5) / meta.scale).floor(), maxX);
        final (sx, sy) = _uprightToSensor(frame, rx, ry);

        final y = frame.yBytes[sy * frame.yRowStride + sx];
        final uvIndex =
            (sy >> 1) * frame.uvRowStride + (sx >> 1) * frame.uvPixelStride;
        final u = frame.uBytes[uvIndex] - 128;
        final v = frame.vBytes[uvIndex] - 128;

        final idx = rowBase + ox;
        tensor[idx] = _unit(y + 1.402 * v);
        tensor[plane + idx] = _unit(y - 0.344136 * u - 0.714136 * v);
        tensor[2 * plane + idx] = _unit(y + 1.772 * u);
      }
    }
    return YoloInput(tensor: tensor, meta: meta);
  }

  /// Picks the highest-confidence person (>= [detConf]) from the flattened
  /// [1,56,8400] output and maps its 17 keypoints into upright image pixels.
  /// Returns `null` when no person passes the detection threshold.
  static List<Keypoint2D>? decodeBestPerson(
    Float32List output,
    LetterboxMeta meta,
  ) {
    if (output.length != channels * anchors) return null;

    const confOffset = 4 * anchors;
    var best = -1;
    var bestConf = detConf;
    for (var j = 0; j < anchors; j++) {
      final conf = output[confOffset + j];
      if (conf >= bestConf) {
        bestConf = conf;
        best = j;
      }
    }
    if (best < 0) return null;

    return List<Keypoint2D>.unmodifiable(
      List<Keypoint2D>.generate(keypointCount, (k) {
        final base = (5 + k * 3) * anchors + best;
        return Keypoint2D(
          x: (output[base] - meta.padLeft) / meta.scale,
          y: (output[base + anchors] - meta.padTop) / meta.scale,
          conf: output[base + 2 * anchors],
        );
      }),
    );
  }

  /// Maps an upright pixel back to the sensor buffer for a clockwise rotation.
  static (int, int) _uprightToSensor(YuvFrame f, int rx, int ry) {
    return switch (f.rotationDegrees) {
      90 => (ry, f.height - 1 - rx),
      180 => (f.width - 1 - rx, f.height - 1 - ry),
      270 => (f.width - 1 - ry, rx),
      _ => (rx, ry),
    };
  }

  static double _unit(double c) {
    if (c <= 0) return 0;
    if (c >= 255) return 1;
    return c / 255;
  }

  static int _clamp(int v, int max) => v < 0 ? 0 : (v > max ? max : v);

  static double _min(double a, double b) => a < b ? a : b;
}
