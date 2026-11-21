import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// TEMPORARY on-device latency benchmark of pose-model variants pushed to
/// `/data/user/0/id.parkinstep.parkinstep/files/bench/yolo26n-pose-<size>.onnx`
/// (via run-as), each on CPU (2 threads) and NNAPI fp16.
/// Enabled with `--dart-define=PARKIN_ORT_BENCH=true`.
abstract final class OrtBenchmark {
  static const bool enabled = bool.fromEnvironment('PARKIN_ORT_BENCH');
  static const String _benchDir =
      '/data/user/0/id.parkinstep.parkinstep/files/bench';

  static Future<void> run(Uint8List bundledModel) async {
    final files = <(int, Uint8List)>[(640, bundledModel)];
    final dir = Directory(_benchDir);
    if (dir.existsSync()) {
      for (final f in dir.listSync().whereType<File>()) {
        final m = RegExp(r'-(\d+)\.onnx$').firstMatch(f.path);
        if (m != null) files.add((int.parse(m.group(1)!), f.readAsBytesSync()));
      }
    }
    files.sort((a, b) => b.$1.compareTo(a.$1));
    debugPrint('ORT bench: sizes ${files.map((f) => f.$1).toList()}');

    for (final (size, bytes) in files) {
      for (final nnapi in <bool>[false, true]) {
        final label = '$size-${nnapi ? 'nnapi' : 'cpu'}';
        try {
          final options = OrtSessionOptions()
            ..setIntraOpNumThreads(2)
            ..setSessionGraphOptimizationLevel(
              GraphOptimizationLevel.ortEnableAll,
            );
          if (nnapi) options.appendNnapiProvider(NnapiFlags.useFp16);
          final session = OrtSession.fromBuffer(bytes, options);
          options.release();
          final address = session.address;
          final times = await Isolate.run(() => _time(address, size));
          session.release();
          times.sort();
          debugPrint(
            'ORT bench $label: median=${times[times.length ~/ 2]}ms '
            'min=${times.first}ms all=$times',
          );
        } on Object catch (e) {
          debugPrint('ORT bench $label FAILED: $e');
        }
      }
    }
    debugPrint('ORT bench SUMMARY done');
  }

  static List<int> _time(int address, int size) {
    final session = OrtSession.fromAddress(address);
    final runOptions = OrtRunOptions();
    final n = 3 * size * size;
    final tensor = Float32List(n)..fillRange(0, n, 0.45);
    final out = <int>[];
    for (var i = 0; i < 10; i++) {
      final input = OrtValueTensor.createTensorWithDataList(tensor, [
        1,
        3,
        size,
        size,
      ]);
      final sw = Stopwatch()..start();
      final outputs = session.run(runOptions, {'images': input});
      final ms = sw.elapsedMilliseconds;
      for (final o in outputs) {
        o?.release();
      }
      input.release();
      if (i >= 2) out.add(ms); // skip warm-up runs
    }
    runOptions.release();
    return out;
  }
}
