import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../domain/value_objects/keypoint_2d.dart';
import 'yolo_pose_codec.dart';

/// Output of one camera frame processed by [PoseWorker].
class PoseWorkerResult {
  const PoseWorkerResult({
    required this.keypoints,
    required this.meta,
    required this.preprocessMs,
    required this.inferenceMs,
  });

  /// Main person's 17 COCO keypoints in upright image pixels, or `null`.
  final List<Keypoint2D>? keypoints;
  final LetterboxMeta meta;
  final int preprocessMs;
  final int inferenceMs;
}

/// Long-lived background isolate running YUV -> letterbox ->
/// `yolo26n-pose.onnx` -> main-person decode for each frame, so the UI isolate
/// never touches per-pixel work or the 56x8400 output tensor.
///
/// The ORT session (NNAPI fp16, CPU fallback) is created and owned by the
/// worker, so the multi-second NNAPI compilation never blocks the UI isolate.
/// Only one frame is processed at a time.
class PoseWorker {
  PoseWorker._(this._isolate, this._requests, this._responses);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _responses;
  Completer<PoseWorkerResult>? _pending;
  bool _closed = false;

  /// Spawns the worker and builds the pose session from [model] inside it.
  /// Completes once the session is ready to run frames.
  static Future<PoseWorker> spawn(
    TransferableTypedData model, {
    required int cpuThreads,
    bool useNnapi = true,
  }) async {
    final responses = ReceivePort();
    final handshake = Completer<SendPort>();
    PoseWorker? worker;
    responses.listen((message) {
      if (!handshake.isCompleted) {
        if (message is SendPort) {
          handshake.complete(message);
        } else {
          handshake.completeError(StateError('Pose worker: $message'));
        }
        return;
      }
      worker?._onMessage(message);
    });
    final isolate = await Isolate.spawn(_workerMain, (
      responses.sendPort,
      model,
      cpuThreads,
      useNnapi,
    ), debugName: 'parkin-pose-worker');
    final SendPort requests;
    try {
      // NNAPI compiles the graph on first load (~6 s on mid-range phones).
      requests = await handshake.future.timeout(const Duration(seconds: 60));
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      responses.close();
      rethrow;
    }
    return worker = PoseWorker._(isolate, requests, responses);
  }

  void _onMessage(Object? message) {
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    if (message is PoseWorkerResult) {
      pending.complete(message);
    } else {
      pending.completeError(StateError('Pose worker: $message'));
    }
  }

  /// Processes one frame. Callers must await before sending the next one.
  Future<PoseWorkerResult> process(YuvFrame frame) {
    if (_closed) return Future.error(StateError('Pose worker closed.'));
    if (_pending != null) {
      return Future.error(StateError('Pose worker busy.'));
    }
    final completer = Completer<PoseWorkerResult>();
    _pending = completer;
    _requests.send(frame);
    return completer.future;
  }

  /// Stops the isolate after its current frame and releases its session.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final exited = ReceivePort();
    _isolate.addOnExitListener(exited.sendPort);
    _requests.send(null);
    await exited.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => _isolate.kill(priority: Isolate.immediate),
    );
    exited.close();
    _responses.close();
    final pending = _pending;
    _pending = null;
    pending?.completeError(StateError('Pose worker closed.'));
  }

  static void _workerMain((SendPort, TransferableTypedData, int, bool) args) {
    final (replies, model, cpuThreads, useNnapi) = args;
    final OrtSession session;
    try {
      session = _createSession(
        model.materialize().asUint8List(),
        cpuThreads,
        useNnapi: useNnapi,
      );
    } on Object catch (error) {
      replies.send('session load failed: $error');
      return;
    }
    final runOptions = OrtRunOptions();
    final requests = ReceivePort();
    replies.send(requests.sendPort);

    requests.listen((message) {
      if (message is! YuvFrame) {
        runOptions.release();
        session.release();
        requests.close();
        return;
      }
      try {
        replies.send(_processFrame(session, runOptions, message));
      } on Object catch (error) {
        replies.send(error.toString());
      }
    });
  }

  static OrtSession _createSession(
    Uint8List model,
    int cpuThreads, {
    required bool useNnapi,
  }) {
    // ORT keeps one ref-counted environment per process; this only binds it
    // to this isolate's Dart wrapper.
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(cpuThreads)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    if (useNnapi) {
      try {
        // NNAPI fp16 offloads ~97% of nodes to the phone's NPU/GPU
        // (138 ms vs 243 ms CPU on SM-A346E); the rest falls back to CPU.
        options.appendNnapiProvider(NnapiFlags.useFp16);
      } on Object {
        // NNAPI unavailable: the session runs on the CPU provider only.
      }
    }
    try {
      return OrtSession.fromBuffer(model, options);
    } finally {
      options.release();
    }
  }

  static PoseWorkerResult _processFrame(
    OrtSession session,
    OrtRunOptions runOptions,
    YuvFrame frame,
  ) {
    final watch = Stopwatch()..start();
    final input = YoloPoseCodec.preprocess(frame);
    final preprocessMs = watch.elapsedMilliseconds;

    final inputValue = OrtValueTensor.createTensorWithDataList(
      input.tensor,
      const <int>[1, 3, YoloPoseCodec.inputSize, YoloPoseCodec.inputSize],
    );
    List<OrtValue?> outputs = const <OrtValue?>[];
    Float32List? output;
    try {
      outputs = session.run(runOptions, <String, OrtValue>{
        'images': inputValue,
      });
      final first = outputs.isEmpty ? null : outputs.first;
      if (first != null) {
        output = _copyFloats(
          first,
          YoloPoseCodec.channels * YoloPoseCodec.anchors,
        );
      }
    } finally {
      for (final o in outputs) {
        o?.release();
      }
      inputValue.release();
    }
    final inferenceMs = watch.elapsedMilliseconds - preprocessMs;

    return PoseWorkerResult(
      keypoints: output == null
          ? null
          : YoloPoseCodec.decodeMainPerson(output, input.meta),
      meta: input.meta,
      preprocessMs: preprocessMs,
      inferenceMs: inferenceMs,
    );
  }

  /// Copies a float32 tensor straight from ORT memory, skipping the nested
  /// `List<List<List<double>>>` that `OrtValue.value` would allocate.
  static Float32List _copyFloats(OrtValue value, int count) {
    final getData = OrtEnv.instance.ortApiPtr.ref.GetTensorMutableData
        .cast<
          NativeFunction<
            Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>)
          >
        >()
        .asFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>)
        >();
    final out = calloc<Pointer<Void>>();
    try {
      final status = getData(value.ptr.cast<Void>(), out);
      if (status.address != 0) {
        throw StateError('GetTensorMutableData failed.');
      }
      return Float32List.fromList(out.value.cast<Float>().asTypedList(count));
    } finally {
      calloc.free(out);
    }
  }
}
