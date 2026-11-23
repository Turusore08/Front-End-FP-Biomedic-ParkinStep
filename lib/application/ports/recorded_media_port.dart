import '../../domain/entities/fog_episode_item.dart';
import '../../domain/entities/recorded_pose_track.dart';

/// Metadata for a standalone exported MP4 containing burned-in skeleton graphics.
class ExportedSkeletonVideoResult {
  const ExportedSkeletonVideoResult({
    required this.savedPath,
    required this.savedToGallery,
    required this.sizeBytes,
  });

  final String savedPath;
  final bool savedToGallery;
  final int sizeBytes;
}

/// Port managing app-private storage, manual deletion, and skeleton MP4 export
/// of locally recorded screening videos and extracted 17-COCO pose tracks.
abstract interface class RecordedMediaPort {
  Future<({String videoPath, String poseTrackPath})> saveSessionMedia({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
  });

  Future<RecordedPoseTrack?> loadPoseTrack(String poseTrackPath);

  Future<void> deleteSessionMedia({
    String? videoPath,
    String? poseTrackPath,
  });

  Future<void> deleteAllSessionMedia();

  Future<ExportedSkeletonVideoResult> exportSkeletonMp4({
    required String sessionId,
    required String sourceVideoPath,
    required RecordedPoseTrack poseTrack,
    required List<FogEpisodeItem> episodes,
  });
}
