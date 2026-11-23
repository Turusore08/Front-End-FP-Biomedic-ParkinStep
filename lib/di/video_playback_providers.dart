import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/recorded_media_port.dart';
import '../application/ports/video_playback_port.dart';
import '../infrastructure/video/local_recorded_media_adapter.dart';
import '../infrastructure/video/native_video_player_adapter.dart';

final recordedMediaPortProvider = Provider<RecordedMediaPort>(
  (ref) => LocalRecordedMediaAdapter(),
);

final videoPlaybackPortProvider = Provider<VideoPlaybackPort>(
  (ref) => NativeVideoPlayerAdapter(),
);
