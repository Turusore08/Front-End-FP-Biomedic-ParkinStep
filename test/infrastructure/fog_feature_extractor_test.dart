import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinstep/infrastructure/edge_ai/fog_feature_extractor.dart';

/// Golden parity against the notebook DSP + `extract_fft_kinematic_features`,
/// generated from real trial `PDFE16_1.mp4` (test split) at 15 Hz with an
/// injected occlusion (frames 40-42, L_Ankle) and spike (frame 90, R_Ankle x).
void main() {
  final golden = jsonDecode(
    File('test/fixtures/fog_golden_pdfe16_1.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final lb6 = (golden['lb6']! as List<Object?>).cast<List<Object?>>();
  final windows = (golden['windows']! as List<Object?>)
      .cast<Map<String, Object?>>();

  Float32List frameAt(int t) {
    final out = Float32List(18);
    final joints = lb6[t].cast<List<Object?>>();
    for (var v = 0; v < 6; v++) {
      for (var c = 0; c < 3; c++) {
        out[v * 3 + c] = (joints[v][c]! as num).toDouble();
      }
    }
    return out;
  }

  test('emits windows at the same buffer lengths as the reference', () {
    final extractor = FogFeatureExtractor();
    final emittedAt = <int>[];
    for (var t = 0; t < lb6.length; t++) {
      if (extractor.pushLb6(frameAt(t)) != null) {
        emittedAt.add(extractor.bufferLength);
      }
    }
    expect(
      emittedAt,
      windows.map((w) => (w['bufferLength']! as num).toInt()).toList(),
    );
  });

  test('126 features match NumPy reference for every window', () {
    final extractor = FogFeatureExtractor();
    var w = 0;
    var worst = 0.0;
    var worstAt = '';
    for (var t = 0; t < lb6.length; t++) {
      final result = extractor.pushLb6(frameAt(t));
      if (result == null) continue;
      final expected = (windows[w]['features']! as List<Object?>)
          .map((e) => (e! as num).toDouble())
          .toList();
      expect(result.features, hasLength(FogFeatureExtractor.featureCount));
      for (var i = 0; i < expected.length; i++) {
        final diff = (result.features[i] - expected[i]).abs();
        final rel = diff / (expected[i].abs() + 1e-3);
        if (rel > worst) {
          worst = rel;
          worstAt =
              'window $w feature $i: ${result.features[i]} vs ${expected[i]}';
        }
      }
      w++;
    }
    expect(w, windows.length);
    expect(worst, lessThan(1e-4), reason: worstAt);
  });

  test(
    'snapshot computed in a background isolate equals inline result',
    () async {
      final syncExtractor = FogFeatureExtractor();
      final snapExtractor = FogFeatureExtractor();
      var compared = 0;
      for (var t = 0; t < lb6.length; t++) {
        final frame = frameAt(t);
        final inline = syncExtractor.pushLb6(Float32List.fromList(frame));
        final snapshot = snapExtractor.pushLb6Snapshot(frame);
        expect(snapshot == null, inline == null);
        if (snapshot == null || inline == null) continue;

        final isolated = await Isolate.run(
          () => FogFeatureExtractor.computeWindow(snapshot),
        );
        expect(isolated.features, inline.features);
        expect(isolated.freezeIndexAnkle, inline.freezeIndexAnkle);
        expect(isolated.isLowQuality, inline.isLowQuality);
        compared++;
      }
      expect(compared, windows.length);
    },
  );

  group('DSP primitives', () {
    test('np.gradient edges are one-sided', () {
      final g = FogFeatureExtractor.gradient(
        Float32List.fromList(<double>[1, 4, 9, 16]),
      );
      expect(g, <double>[3, 4, 6, 7]);
    });

    test('Hampel replaces an isolated spike with the rolling median', () {
      final sig = Float32List.fromList(<double>[
        1,
        1.1,
        0.9,
        1,
        50,
        1,
        1.05,
        0.95,
        1,
      ]);
      final out = FogFeatureExtractor.hampel(sig);
      expect(out[4], closeTo(1.0, 1e-6));
      expect(out[1], closeTo(1.1, 1e-6));
    });
  });

  group('Post-recording Batch Exact DSP', () {
    test('computeAllWindowsBatch processes entire trial with validLb6Ratio & aligned window indices', () {
      final flat = Float32List(lb6.length * 18);
      for (var t = 0; t < lb6.length; t++) {
        flat.setRange(t * 18, (t + 1) * 18, frameAt(t));
      }
      final batch = FogFeatureExtractor.computeAllWindowsBatch(flat, lb6.length);
      expect(batch.validLb6Ratio, greaterThan(0.5));
      expect(batch.validLb6Ratio, lessThanOrEqualTo(1.0));
      expect(batch.windows, isNotEmpty);
      expect(batch.windows.first.windowIdx, 0);
      expect(batch.windows.first.startSec, 0.0);
      expect(batch.windows.first.endSec, closeTo(2.0, 1e-6));
      expect(batch.windows.first.features, hasLength(126));
      expect(batch.windows.first.freezeIndexAnkle.isFinite, isTrue);
      expect(batch.windows.first.locomotorEnergyAnkle.isFinite, isTrue);
      expect(batch.windows.first.freezeEnergyAnkle.isFinite, isTrue);
      expect(batch.windows.first.bilateralAsymAnkle.isFinite, isTrue);

      final tooShort = FogFeatureExtractor.computeAllWindowsBatch(
        Float32List(10 * 18),
        10,
      );
      expect(tooShort.windows, isEmpty);
    });
  });
}
