import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/infrastructure/edge_ai/yolo_pose_codec.dart';

void main() {
  group('YoloPoseCodec.letterboxFor', () {
    test('matches Ultralytics LetterBox(auto=False) for 1280x720', () {
      final meta = YoloPoseCodec.letterboxFor(1280, 720);
      expect(meta.scale, closeTo(0.5, 1e-9));
      expect(meta.padLeft, 0);
      expect(meta.padTop, 140);
    });

    test('portrait 480x640 pads left/right', () {
      final meta = YoloPoseCodec.letterboxFor(480, 640);
      expect(meta.scale, closeTo(1.0, 1e-9));
      expect(meta.padLeft, 80);
      expect(meta.padTop, 0);
    });
  });

  group('YoloPoseCodec.decodeBestPerson', () {
    const a = YoloPoseCodec.anchors;

    Float32List outputWith({
      required int anchor,
      required double conf,
      required double kx,
      required double ky,
    }) {
      final out = Float32List(YoloPoseCodec.channels * a);
      out[4 * a + anchor] = conf;
      for (var k = 0; k < 17; k++) {
        final base = (5 + k * 3) * a + anchor;
        out[base] = kx;
        out[base + a] = ky;
        out[base + 2 * a] = 0.9;
      }
      return out;
    }

    test('returns null below DET_CONF 0.25', () {
      final out = outputWith(anchor: 10, conf: 0.2, kx: 1, ky: 1);
      final meta = YoloPoseCodec.letterboxFor(1280, 720);
      expect(YoloPoseCodec.decodeBestPerson(out, meta), isNull);
    });

    test('picks highest confidence anchor and undoes letterbox', () {
      final out = outputWith(anchor: 42, conf: 0.87, kx: 381.17, ky: 321.82);
      out[4 * a + 7] = 0.5; // weaker second person
      final meta = YoloPoseCodec.letterboxFor(1280, 720);

      final kps = YoloPoseCodec.decodeBestPerson(out, meta)!;
      expect(kps, hasLength(17));
      expect(kps[11].x, closeTo(762.34, 1e-3));
      expect(kps[11].y, closeTo((321.82 - 140) * 2, 1e-3));
      expect(kps[11].conf, closeTo(0.9, 1e-6));
    });

    test('rejects malformed output length', () {
      final meta = YoloPoseCodec.letterboxFor(640, 640);
      expect(YoloPoseCodec.decodeBestPerson(Float32List(10), meta), isNull);
    });
  });

  group('YoloPoseCodec.preprocess', () {
    YuvFrame grayFrame({required int rotation, int bright = 255}) {
      const w = 64;
      const h = 32;
      final y = Uint8List(w * h);
      // Mark top-left sensor pixel region bright, rest dark.
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          y[r * w + c] = bright;
        }
      }
      final uv = Uint8List((w ~/ 2) * (h ~/ 2))
        ..fillRange(0, (w ~/ 2) * (h ~/ 2), 128);
      return YuvFrame(
        width: w,
        height: h,
        yBytes: y,
        uBytes: uv,
        vBytes: uv,
        yRowStride: w,
        uvRowStride: w ~/ 2,
        uvPixelStride: 1,
        rotationDegrees: rotation,
      );
    }

    test('rotation 0 keeps landscape and pads with 114', () {
      final input = YoloPoseCodec.preprocess(grayFrame(rotation: 0));
      expect(input.meta.imageWidth, 64);
      expect(input.meta.imageHeight, 32);
      expect(input.meta.padTop, 160);
      expect(input.tensor, hasLength(3 * 640 * 640));
      expect(input.tensor[0], closeTo(114 / 255, 1e-6)); // padding row
      final firstImagePixel = 160 * 640;
      expect(input.tensor[firstImagePixel], closeTo(1.0, 1e-6));
    });

    test('rotation 90 turns sensor top-left into upright top-right', () {
      final input = YoloPoseCodec.preprocess(grayFrame(rotation: 90));
      expect(input.meta.imageWidth, 32);
      expect(input.meta.imageHeight, 64);
      final meta = input.meta;
      final topRight = meta.padTop * 640 + meta.padLeft + 319;
      final topLeft = meta.padTop * 640 + meta.padLeft;
      expect(input.tensor[topRight], closeTo(1.0, 1e-6));
      expect(input.tensor[topLeft], closeTo(0.0, 1e-6));
    });
  });
}
