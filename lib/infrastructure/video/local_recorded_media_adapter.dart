import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../application/ports/recorded_media_port.dart';
import '../../domain/entities/fog_episode_item.dart';
import '../../domain/entities/recorded_pose_track.dart';
import '../edge_ai/onnx_video_session_adapter.dart';

/// App-private disk persistence, zero-fill manual deletion, and burned-in
/// skeleton MP4 exporter backed by Android `SkeletonVideoExporter`.
class LocalRecordedMediaAdapter implements RecordedMediaPort {
  LocalRecordedMediaAdapter({
    MethodChannel? exporterChannel,
    this.fallbackDirProvider,
  }) : _exporterChannel = exporterChannel ??
           const MethodChannel('id.parkinstep.parkinstep/video_exporter');

  final MethodChannel _exporterChannel;
  final Directory Function()? fallbackDirProvider;

  Future<Directory> _resolveSessionsDir() async {
    String? basePath;
    if (fallbackDirProvider == null) {
      try {
        basePath = await _exporterChannel.invokeMethod<String>('getAppFilesDir');
      } on MissingPluginException {
        basePath = null;
      } on PlatformException {
        basePath = null;
      }
    }
    final root = basePath != null && basePath.isNotEmpty
        ? Directory(basePath)
        : (fallbackDirProvider?.call() ?? Directory.systemTemp);
    final dir = Directory('${root.path}/parkinstep_sessions');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<({String videoPath, String poseTrackPath})> saveSessionMedia({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
  }) async {
    final safeId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final dir = await _resolveSessionsDir();
    final poseFile = File('${dir.path}/$safeId.pose.json');
    await poseFile.writeAsString(jsonEncode(poseTrack.toJsonMap()), flush: true);

    if (sourceVideoPath.startsWith('preview://')) {
      return (videoPath: sourceVideoPath, poseTrackPath: poseFile.path);
    }

    final src = File(sourceVideoPath);
    final dest = File('${dir.path}/$safeId.mp4');
    if (src.existsSync()) {
      await src.copy(dest.path);
      if (src.path != dest.path) {
        await OnnxVideoSessionAdapter.secureZeroAndDeleteFile(src);
      }
    }
    return (videoPath: dest.path, poseTrackPath: poseFile.path);
  }

  @override
  Future<RecordedPoseTrack?> loadPoseTrack(String poseTrackPath) async {
    if (poseTrackPath.isEmpty) return null;
    final file = File(poseTrackPath);
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return RecordedPoseTrack.fromJsonMap(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSessionMedia({
    String? videoPath,
    String? poseTrackPath,
  }) async {
    if (videoPath != null &&
        videoPath.isNotEmpty &&
        !videoPath.startsWith('preview://')) {
      await OnnxVideoSessionAdapter.secureZeroAndDeleteFile(File(videoPath));
    }
    if (poseTrackPath != null && poseTrackPath.isNotEmpty) {
      await OnnxVideoSessionAdapter.secureZeroAndDeleteFile(File(poseTrackPath));
    }
  }

  @override
  Future<void> deleteAllSessionMedia() async {
    final dir = await _resolveSessionsDir();
    if (!dir.existsSync()) return;
    final entities = dir.listSync();
    for (final entity in entities) {
      if (entity is File) {
        await OnnxVideoSessionAdapter.secureZeroAndDeleteFile(entity);
      }
    }
  }

  @override
  Future<ExportedSkeletonVideoResult> exportSkeletonMp4({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
    required List<FogEpisodeItem> episodes,
  }) async {
    final safeId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (sourceVideoPath.startsWith('preview://')) {
      final dir = await _resolveSessionsDir();
      final out = File('${dir.path}/parkinstep_skeleton_$safeId.mp4');
      await out.writeAsBytes(
        utf8.encode('PARKINSTEP_PREVIEW_SKELETON_MP4:$safeId:${poseTrack.frames.length}'),
        flush: true,
      );
      return ExportedSkeletonVideoResult(
        savedPath: out.path,
        savedToGallery: false,
        sizeBytes: await out.length(),
      );
    }

    final frameCount = poseTrack.frames.length;
    final timestamps = Int32List(frameCount);
    final fogFlags = Uint8List(frameCount);
    final keypointsFlat = Float32List(frameCount * 51);

    for (var i = 0; i < frameCount; i++) {
      final f = poseTrack.frames[i];
      timestamps[i] = f.timestampMs;
      final tSec = f.timestampMs / 1000.0;
      fogFlags[i] =
          episodes.any((e) => tSec >= e.startSec && tSec <= e.endSec) ? 1 : 0;
      final base = i * 51;
      for (var k = 0; k < 17 && k < f.keypoints17.length; k++) {
        final kp = f.keypoints17[k];
        keypointsFlat[base + k * 3] = kp.x;
        keypointsFlat[base + k * 3 + 1] = kp.y;
        keypointsFlat[base + k * 3 + 2] = kp.conf;
      }
    }

    final raw = await _exporterChannel.invokeMapMethod<Object?, Object?>(
      'exportSkeletonVideo',
      <String, Object?>{
        'sourceVideoPath': sourceVideoPath,
        'sessionId': safeId,
        'srcWidth': poseTrack.imageWidth,
        'srcHeight': poseTrack.imageHeight,
        'timestampsMs': timestamps,
        'fogFlags': fogFlags,
        'keypointsFlat': keypointsFlat,
        'targetFps': 15,
      },
    );

    if (raw == null) {
      throw StateError('Gagal mengekspor video skeleton MP4.');
    }

    return ExportedSkeletonVideoResult(
      savedPath: (raw['savedPath'] as String?) ?? '',
      savedToGallery: raw['gallerySaved'] == true,
      sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}
