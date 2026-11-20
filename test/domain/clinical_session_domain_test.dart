import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/domain/value_objects/calibrated_risk_score.dart';
import 'package:parkinstep/domain/value_objects/keypoint_2d.dart';
import 'package:parkinstep/presentation/features/live_session/mappers/camera_coordinate_mapper.dart';

void main() {
  group('Clinical Risk Calibration, Keypoint2D & CameraCoordinateMapper', () {
    test('CalibratedRiskScore maps thr_val -> 50%, 0 -> 0%, 1 -> 100%, and clamps bad values', () {
      expect(CalibratedRiskScore.fromRawProbability(0.0), 0.0);
      expect(CalibratedRiskScore.fromRawProbability(0.13), closeTo(25.0, 1e-6));
      expect(CalibratedRiskScore.fromRawProbability(0.26), closeTo(50.0, 1e-6));
      expect(CalibratedRiskScore.fromRawProbability(0.63), closeTo(75.0, 1e-6));
      expect(CalibratedRiskScore.fromRawProbability(1.0), 100.0);

      // Custom threshold (e.g. Pure_Bi-Mamba thr = 0.15)
      expect(
        CalibratedRiskScore.fromRawProbability(0.15, threshold: 0.15),
        closeTo(50.0, 1e-6),
      );
      expect(
        CalibratedRiskScore.fromRawProbability(-0.5),
        0.0,
      );
      expect(
        CalibratedRiskScore.fromRawProbability(double.nan),
        0.0,
      );
      expect(
        CalibratedRiskScore.fromRawProbability(2.0),
        100.0,
      );
    });

    test('Keypoint2D enforces 0.20 valid confidence threshold', () {
      const lowConf = Keypoint2D(x: 100, y: 200, conf: 0.199);
      const exactConf = Keypoint2D(x: 100, y: 200, conf: 0.20);
      expect(lowConf.isValid, isFalse);
      expect(exactConf.isValid, isTrue);
    });

    test('CameraCoordinateMapper computes BoxFit.cover projection, rotation swap & front mirror', () {
      // Sensor 480x640 into 480x320 viewport: scale = max(1.0, 0.5) = 1.0,
      // drawnH = 640, dy = (320 - 640) * 0.5 = -160
      const portraitCover = CameraCoordinateMapper(
        imageWidth: 480,
        imageHeight: 640,
        viewWidth: 480,
        viewHeight: 320,
      );
      expect(
        portraitCover.mapPoint(240, 320),
        const Offset(240.0, 160.0),
      );

      // Front camera mirror flips X around viewWidth
      const mirrored = CameraCoordinateMapper(
        imageWidth: 480,
        imageHeight: 640,
        viewWidth: 480,
        viewHeight: 320,
        isFrontCameraMirrored: true,
      );
      expect(
        mirrored.mapPoint(100, 320),
        const Offset(380.0, 160.0),
      );

      // 90-degree sensor rotation swaps 640x480 -> effective 480x640
      const rotated90 = CameraCoordinateMapper(
        imageWidth: 640,
        imageHeight: 480,
        viewWidth: 480,
        viewHeight: 640,
        sensorRotationDegrees: 90,
      );
      expect(
        rotated90.mapPoint(120, 200),
        const Offset(120.0, 200.0),
      );
    });
  });
}
