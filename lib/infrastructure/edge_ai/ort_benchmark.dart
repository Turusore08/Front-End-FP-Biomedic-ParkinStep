import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'yolo_pose_codec.dart';

/// TEMPORARY on-device check of NNAPI fp16 vs CPU for the pose model:
/// latency plus keypoint parity on real letterboxed frames pushed to
/// `/data/user/0/id.parkinstep.parkinstep/files/parity/frame{k}.f32` (via run-as).
/// Enabled with `--dart-define=PARKIN_ORT_BENCH=true`.
abstract final class OrtBenchmark {
  static const bool enabled = bool.fromEnvironment('PARKIN_ORT_BENCH');
  static const String _parityDir =
      '/data/user/0/id.parkinstep.parkinstep/files/parity';

  static Future<void> run(Uint8List model) async {
    final frames = <Float32List>[];
    for (var k = 0; k < 16; k++) {
      final f = File('$_parityDir/frame$k.f32');
      if (!f.existsSync()) break;
      frames.add(f.readAsBytesSync().buffer.asFloat32List());
    }
    debugPrint('ORT parity: ${frames.length} frames loaded');

    final cpu = _create(model, nnapi: false);
    final nnapi = _create(model, nnapi: true);
    try {
      final cpuAddr = cpu.address;
      final nnapiAddr = nnapi.address;
      final report = await Isolate.run(
        () => _compare(cpuAddr, nnapiAddr, frames),
      );
      report.forEach(debugPrint);
    } on Object catch (e) {
      debugPrint('ORT parity FAILED: $e');
    } finally {
      cpu.release();
      nnapi.release();
    }
  }

  static OrtSession _create(Uint8List model, {required bool nnapi}) {
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    if (nnapi) options.appendNnapiProvider(NnapiFlags.useFp16);
    final session = OrtSession.fromBuffer(model, options);
    options.release();
    return session;
  }

  static List<String> _compare(
    int cpuAddr,
    int nnapiAddr,
    List<Float32List> frames,
  ) {
    final cpu = OrtSession.fromAddress(cpuAddr);
    final nnapi = OrtSession.fromAddress(nnapiAddr);
    final runOptions = OrtRunOptions();
    final meta = YoloPoseCodec.letterboxFor(1280, 720);
    final lines = <String>[];
    final cpuMs = <int>[];
    final nnMs = <int>[];
    var worstPx = 0.0;
    var worstLb6Px = 0.0;
    var sumPx = 0.0;
    var nPx = 0;
    var worstConf = 0.0;
    var personMismatch = 0;

    for (var k = 0; k < frames.length; k++) {
      final (a, ta) = _infer(cpu, runOptions, frames[k]);
      final (b, tb) = _infer(nnapi, runOptions, frames[k]);
      cpuMs.add(ta);
      nnMs.add(tb);
      final ka = YoloPoseCodec.decodeMainPerson(a, meta);
      final kb = YoloPoseCodec.decodeMainPerson(b, meta);
      if ((ka == null) != (kb == null)) {
        personMismatch++;
        continue;
      }
      if (ka == null || kb == null) continue;
      var frameWorst = 0.0;
      for (var j = 0; j < ka.length; j++) {
        final d = math.sqrt(
          math.pow(ka[j].x - kb[j].x, 2) + math.pow(ka[j].y - kb[j].y, 2),
        );
        sumPx += d;
        nPx++;
        frameWorst = math.max(frameWorst, d);
        if (j >= 11) worstLb6Px = math.max(worstLb6Px, d);
        worstConf = math.max(worstConf, (ka[j].conf - kb[j].conf).abs());
      }
      worstPx = math.max(worstPx, frameWorst);
      lines.add(
        'ORT parity frame$k: cpu=${ta}ms nnapi=${tb}ms '
        'maxKpDiff=${frameWorst.toStringAsFixed(2)}px',
      );
    }
    runOptions.release();
    cpuMs.sort();
    nnMs.sort();
    lines.add(
      'ORT parity SUMMARY (1280x720 px): meanKpDiff='
      '${(nPx == 0 ? 0 : sumPx / nPx).toStringAsFixed(2)}px '
      'maxKpDiff=${worstPx.toStringAsFixed(2)}px '
      'maxLb6Diff=${worstLb6Px.toStringAsFixed(2)}px '
      'maxConfDiff=${worstConf.toStringAsFixed(4)} '
      'personMismatch=$personMismatch '
      'medianCpu=${cpuMs.isEmpty ? 0 : cpuMs[cpuMs.length ~/ 2]}ms '
      'medianNnapi=${nnMs.isEmpty ? 0 : nnMs[nnMs.length ~/ 2]}ms',
    );
    return lines;
  }

  static (Float32List, int) _infer(
    OrtSession session,
    OrtRunOptions runOptions,
    Float32List tensor,
  ) {
    final input = OrtValueTensor.createTensorWithDataList(tensor, const [
      1,
      3,
      YoloPoseCodec.inputSize,
      YoloPoseCodec.inputSize,
    ]);
    final sw = Stopwatch()..start();
    final outputs = session.run(runOptions, {'images': input});
    final ms = sw.elapsedMilliseconds;
    final value = outputs.first!.value as List;
    final out = Float32List(YoloPoseCodec.channels * YoloPoseCodec.anchors);
    var o = 0;
    for (final row in value.first as List) {
      for (final v in row as List) {
        out[o++] = (v as num).toDouble();
      }
    }
    for (final v in outputs) {
      v?.release();
    }
    input.release();
    return (out, ms);
  }
}
