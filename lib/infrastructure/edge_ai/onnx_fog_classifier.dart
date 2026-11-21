import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'fog_feature_extractor.dart';

/// `lgbm_b15hz.onnx` (LightGBM+FFT, Scenario B @ 15 Hz) on ONNX Runtime.
/// Input `input` float32[1,126] RAW features; output `probabilities` [1,2].
/// Compare `p(FoG)` against [threshold] (`thr_val = 0.26`), not the model's
/// own `label` output which uses 0.5.
class OnnxFogClassifier {
  OnnxFogClassifier({this.modelAssetPath = 'assets/models/lgbm_b15hz.onnx'});

  final String modelAssetPath;

  static const double threshold = 0.26;
  static const String _inputName = 'input';
  static const String _probOutput = 'probabilities';

  OrtSession? _session;

  bool get isLoaded => _session != null;

  /// Loads the model once. Call after `OrtEnv.instance.init()`.
  Future<void> load() async {
    if (_session != null) return;
    final raw = await rootBundle.load(modelAssetPath);
    final options = OrtSessionOptions()..setIntraOpNumThreads(1);
    _session = OrtSession.fromBuffer(raw.buffer.asUint8List(), options);
    options.release();
  }

  /// Returns `p(FoG)` in `[0, 1]`, or `null` if the model is not loaded.
  double? predict(Float32List features) {
    final session = _session;
    if (session == null) return null;
    if (features.length != FogFeatureExtractor.featureCount) {
      throw ArgumentError.value(
        features.length,
        'features',
        'expected ${FogFeatureExtractor.featureCount} values',
      );
    }

    final input = OrtValueTensor.createTensorWithDataList(features, <int>[
      1,
      FogFeatureExtractor.featureCount,
    ]);
    final runOptions = OrtRunOptions();
    final outputs = session.run(
      runOptions,
      <String, OrtValue>{_inputName: input},
      <String>[_probOutput],
    );
    try {
      return _positiveProbability(outputs.isEmpty ? null : outputs.first);
    } finally {
      for (final o in outputs) {
        o?.release();
      }
      input.release();
      runOptions.release();
    }
  }

  static double? _positiveProbability(OrtValue? value) {
    final rows = value?.value;
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first;
    if (row is! List || row.length < 2) return null;
    final p = row[1];
    return p is num ? p.toDouble() : null;
  }

  void release() {
    _session?.release();
    _session = null;
  }
}
