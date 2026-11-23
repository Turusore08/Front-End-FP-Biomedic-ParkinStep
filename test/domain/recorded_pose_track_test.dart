import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/entities/recorded_pose_track.dart';
import 'package:parkinstep/domain/value_objects/keypoint_2d.dart';

void main() {
  group('RecordedPoseTrack & TimedPoseFrame', () {
    test('frameAtMs binary search resolves nearest timestamp frame', () {
      const kpA = Keypoint2D(x: 100, y: 200, conf: 0.9);
      const kpB = Keypoint2D(x: 200, y: 300, conf: 0.95);
      final track = RecordedPoseTrack(
        imageWidth: 480,
        imageHeight: 640,
        durationMs: 2000,
        frames: <TimedPoseFrame>[
          TimedPoseFrame(
            timestampMs: 0,
            keypoints17: List<Keypoint2D>.filled(17, kpA),
          ),
          TimedPoseFrame(
            timestampMs: 100,
            keypoints17: List<Keypoint2D>.filled(17, kpB),
          ),
          TimedPoseFrame(
            timestampMs: 200,
            keypoints17: List<Keypoint2D>.filled(17, kpA),
          ),
        ],
      );

      expect(track.frameAtMs(-50)?.timestampMs, 0);
      expect(track.frameAtMs(20)?.timestampMs, 0);
      expect(track.frameAtMs(80)?.timestampMs, 100);
      expect(track.frameAtMs(100)?.timestampMs, 100);
      expect(track.frameAtMs(160)?.timestampMs, 200);
      expect(track.frameAtMs(999)?.timestampMs, 200);

      const emptyTrack = RecordedPoseTrack(
        imageWidth: 480,
        imageHeight: 640,
        durationMs: 0,
        frames: <TimedPoseFrame>[],
      );
      expect(emptyTrack.frameAtMs(50), isNull);
    });

    test('toJsonMap and fromJsonMap round-trip compact pose tracks accurately', () {
      final track = RecordedPoseTrack(
        imageWidth: 480,
        imageHeight: 640,
        durationMs: 133,
        frames: <TimedPoseFrame>[
          TimedPoseFrame(
            timestampMs: 67,
            keypoints17: List<Keypoint2D>.generate(
              17,
              (i) => Keypoint2D(x: 100.0 + i, y: 200.0 + i, conf: 0.85),
            ),
          ),
        ],
      );

      final json = track.toJsonMap();
      final decoded = RecordedPoseTrack.fromJsonMap(json);
      expect(decoded, isNotNull);
      expect(decoded!.imageWidth, 480);
      expect(decoded.imageHeight, 640);
      expect(decoded.durationMs, 133);
      expect(decoded.frames, hasLength(1));
      expect(decoded.frames.first.timestampMs, 67);
      expect(decoded.frames.first.keypoints17, hasLength(17));
      expect(decoded.frames.first.keypoints17[15].x, closeTo(115.0, 0.2));
      expect(decoded.frames.first.keypoints17[15].conf, closeTo(0.85, 0.01));
    });
  });
}
