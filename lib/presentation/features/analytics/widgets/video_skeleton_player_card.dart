import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../application/ports/recorded_media_port.dart';
import '../../../../application/ports/video_playback_port.dart';
import '../../../../di/video_playback_providers.dart';
import '../../../../domain/entities/session_clinical_report.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_progress_pill.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../painters/recorded_skeleton_overlay_painter.dart';

/// Interactive local video replay card showing the recorded test video paired
/// frame-by-frame with the extracted 17-COCO skeleton, optional standalone MP4
/// export with burned-in skeleton, and permanent local deletion control.
class VideoSkeletonPlayerCard extends ConsumerStatefulWidget {
  const VideoSkeletonPlayerCard({
    super.key,
    required this.report,
    required this.onDeleteVideo,
  });

  final SessionClinicalReport report;
  final Future<void> Function() onDeleteVideo;

  @override
  ConsumerState<VideoSkeletonPlayerCard> createState() =>
      _VideoSkeletonPlayerCardState();
}

class _VideoSkeletonPlayerCardState
    extends ConsumerState<VideoSkeletonPlayerCard> {
  late final VideoPlaybackPort _playbackPort;
  late final RecordedMediaPort _mediaPort;

  OpenedVideoPlayback? _opened;
  Timer? _pollTimer;
  int _positionMs = 0;
  int _durationMs = 0;
  bool _isPlaying = false;
  bool _showSkeleton = true;
  bool _isOpening = true;
  bool _isExportingMp4 = false;
  bool _isDeleting = false;
  String? _playerError;
  String? _exportError;
  ExportedSkeletonVideoResult? _exportedVideo;

  bool get _hasMedia =>
      widget.report.recordedVideoPath != null &&
      widget.report.recordedVideoPath!.isNotEmpty &&
      widget.report.poseTrack != null;

  @override
  void initState() {
    super.initState();
    _playbackPort = ref.read(videoPlaybackPortProvider);
    _mediaPort = ref.read(recordedMediaPortProvider);
    if (_hasMedia) {
      unawaited(_openMedia());
    } else {
      _isOpening = false;
    }
  }

  @override
  void didUpdateWidget(covariant VideoSkeletonPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.recordedVideoPath != widget.report.recordedVideoPath) {
      unawaited(_closeCurrentPlayer());
      _exportedVideo = null;
      _exportError = null;
      if (_hasMedia) {
        unawaited(_openMedia());
      } else {
        setState(() {
          _isOpening = false;
          _isPlaying = false;
          _positionMs = 0;
          _durationMs = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final current = _opened;
    _opened = null;
    if (current != null) {
      unawaited(_playbackPort.dispose(current.playerId));
    }
    super.dispose();
  }

  Future<void> _closeCurrentPlayer() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    final current = _opened;
    _opened = null;
    if (current != null) {
      await _playbackPort.dispose(current.playerId);
    }
  }

  Future<void> _openMedia() async {
    final path = widget.report.recordedVideoPath;
    final track = widget.report.poseTrack;
    if (path == null || track == null) return;

    if (mounted) {
      setState(() {
        _isOpening = true;
        _playerError = null;
        _positionMs = 0;
        _isPlaying = false;
      });
    }

    try {
      final opened = await _playbackPort.open(
        path,
        fallbackDurationMs: track.durationMs > 0
            ? track.durationMs
            : (widget.report.summary.durationSec * 1000).round(),
        fallbackWidth: track.imageWidth > 0 ? track.imageWidth : 480.0,
        fallbackHeight: track.imageHeight > 0 ? track.imageHeight : 640.0,
      );
      if (!mounted) {
        await _playbackPort.dispose(opened.playerId);
        return;
      }
      setState(() {
        _opened = opened;
        _durationMs = opened.durationMs > 0
            ? opened.durationMs
            : track.durationMs;
        _isOpening = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isOpening = false;
        _playerError =
            'Video rekaman tidak lagi tersedia di penyimpanan perangkat.';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final opened = _opened;
    if (opened == null) return;
    if (_isPlaying) {
      _pollTimer?.cancel();
      _pollTimer = null;
      await _playbackPort.pause(opened.playerId);
      final snap = await _playbackPort.getPosition(opened.playerId);
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _positionMs = snap.positionMs;
      });
    } else {
      await _playbackPort.play(opened.playerId);
      final snap = await _playbackPort.getPosition(opened.playerId);
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _positionMs = snap.positionMs;
      });
      _startPoller();
    }
  }

  void _startPoller() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 66),
      (_) => unawaited(_pollPosition()),
    );
  }

  Future<void> _pollPosition() async {
    final opened = _opened;
    if (opened == null || !mounted || !_isPlaying) return;
    final snap = await _playbackPort.getPosition(opened.playerId);
    if (!mounted) return;
    if (snap.isCompleted || (!snap.isPlaying && snap.positionMs >= snap.durationMs)) {
      _pollTimer?.cancel();
      _pollTimer = null;
      setState(() {
        _isPlaying = false;
        _positionMs = snap.durationMs > 0 ? snap.durationMs : _durationMs;
      });
      return;
    }
    setState(() {
      _positionMs = snap.positionMs;
      if (snap.durationMs > 0) _durationMs = snap.durationMs;
    });
  }

  Future<void> _seekRelative(int deltaMs) async {
    final opened = _opened;
    if (opened == null) return;
    final maxDur = _durationMs > 0 ? _durationMs : opened.durationMs;
    final target = (_positionMs + deltaMs).clamp(0, maxDur);
    await _playbackPort.seekTo(opened.playerId, target);
    final snap = await _playbackPort.getPosition(opened.playerId);
    if (!mounted) return;
    setState(() {
      _positionMs = snap.positionMs;
    });
  }

  Future<void> _exportSkeletonMp4() async {
    final videoPath = widget.report.recordedVideoPath;
    final track = widget.report.poseTrack;
    if (videoPath == null || track == null || _isExportingMp4) return;
    setState(() {
      _isExportingMp4 = true;
      _exportError = null;
    });
    try {
      final res = await _mediaPort.exportSkeletonMp4(
        sessionId: widget.report.summary.sessionId,
        sourceVideoPath: videoPath,
        poseTrack: track,
        episodes: widget.report.episodes,
      );
      if (!mounted) return;
      setState(() {
        _isExportingMp4 = false;
        _exportedVideo = res;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExportingMp4 = false;
        _exportError =
            'Gagal menyimpan video skeleton (.mp4). Silakan coba lagi.';
      });
    }
  }

  Future<void> _handleDeleteVideo() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      await _closeCurrentPlayer();
      await widget.onDeleteVideo();
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMedia || widget.report.videoSecurelyDeleted) {
      return Container(
        key: const Key('video_deleted_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.emeraldSoftBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.normalEmerald),
        ),
        child: Row(
          children: [
            ParkinIcons.offlineShield(
              color: AppColors.emeraldDarkText,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Video rekaman telah dihapus permanen dari perangkat Anda.',
                style: AppTypography.captionBadge(
                  color: AppColors.emeraldDarkText,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final track = widget.report.poseTrack!;
    final activeFrame = track.frameAtMs(_positionMs);
    final posSec = _positionMs / 1000.0;
    final isFogActive = widget.report.episodes.any(
      (ep) => posSec >= ep.startSec && posSec <= ep.endSec,
    );
    final durMs = _durationMs > 0 ? _durationMs : track.durationMs;
    final progress = durMs <= 0 ? 0.0 : (_positionMs / durMs).clamp(0.0, 1.0);
    final aspectW = _opened?.uprightWidth ??
        (track.imageWidth > 0 ? track.imageWidth : 480.0);
    final aspectH = _opened?.uprightHeight ??
        (track.imageHeight > 0 ? track.imageHeight : 640.0);
    final safeAspect = (aspectW / aspectH).clamp(0.4, 2.2);

    return Container(
      key: const Key('video_skeleton_player_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Putar Ulang Video + Skeleton',
            style: AppTypography.cardTitle(size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Periksa kesesuaian 17 titik skeleton terhadap gerakan tubuh Anda.',
            style: AppTypography.bodyLarge(size: 14.0),
          ),
          const SizedBox(height: 12),
          if (_playerError != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amberSoftBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.amberSoftBorder),
              ),
              child: Text(
                _playerError!,
                style: AppTypography.captionBadge(
                  color: AppColors.amberDarkText,
                  weight: FontWeight.w700,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Center(
                child: AspectRatio(
                  aspectRatio: safeAspect,
                  child: ClipRRect(
                    key: const Key('video_skeleton_viewport'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: AppColors.midnightNavy,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildVideoTextureSurface(),
                          if (_showSkeleton && activeFrame != null)
                            RepaintBoundary(
                              child: CustomPaint(
                                key: const Key('recorded_skeleton_custom_paint'),
                                painter: RecordedSkeletonOverlayPainter(
                                  frame: activeFrame,
                                  sourceWidth: track.imageWidth,
                                  sourceHeight: track.imageHeight,
                                  isFogActive: isFogActive,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isFogActive
                                    ? AppColors.alertRed
                                    : AppColors.emeraldSoftBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isFogActive ? 'FoG Terdeteksi' : 'Gerak Normal',
                                style: AppTypography.captionBadge(
                                  color: isFogActive
                                      ? AppColors.pureWhite
                                      : AppColors.emeraldDarkText,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (_isOpening)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.rhythmAqua,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.clinicalAzure,
              backgroundColor: AppColors.iceSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Durasi Putar',
                  style: AppTypography.captionBadge(
                    color: AppColors.mutedSlate,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ParkinProgressPill.formatDuration((_positionMs / 1000).floor())} / '
                '${ParkinProgressPill.formatDuration((durMs / 1000).ceil())}',
                style: AppTypography.captionBadge(
                  color: AppColors.royalNavy,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ParkinPrimaryPillButton(
            key: const Key('video_play_pause_button'),
            label: _isPlaying ? 'Jeda Video' : 'Putar Video',
            leadingIcon: _isPlaying
                ? ParkinIcons.pauseBars(color: AppColors.clinicalAzure)
                : ParkinIcons.playTriangle(color: AppColors.clinicalAzure),
            onPressed: _opened == null ? null : () => unawaited(_togglePlayPause()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallControlButton(
                  buttonKey: const Key('video_rewind_button'),
                  label: '-5 dtk',
                  selected: false,
                  onPressed:
                      _opened == null ? null : () => unawaited(_seekRelative(-5000)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallControlButton(
                  buttonKey: const Key('video_forward_button'),
                  label: '+5 dtk',
                  selected: false,
                  onPressed:
                      _opened == null ? null : () => unawaited(_seekRelative(5000)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallControlButton(
                  buttonKey: const Key('video_skeleton_toggle_button'),
                  label: _showSkeleton ? 'Skeleton: On' : 'Skeleton: Off',
                  selected: _showSkeleton,
                  onPressed: () =>
                      setState(() => _showSkeleton = !_showSkeleton),
                ),
              ),
            ],
          ),
          if (_exportedVideo != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('video_export_status_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.normalEmerald),
                ),
                child: Text(
                  _exportedVideo!.savedToGallery
                      ? 'Video skeleton tersimpan di Galeri: ${_exportedVideo!.savedPath}'
                      : 'Video skeleton tersimpan offline: ${_exportedVideo!.savedPath}',
                  style: AppTypography.captionBadge(
                    color: AppColors.emeraldDarkText,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_exportError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redSoftBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.alertRed),
              ),
              child: Text(
                _exportError!,
                style: AppTypography.captionBadge(
                  color: AppColors.redDarkText,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ParkinSecondaryIceButton(
            key: const Key('video_export_mp4_button'),
            title: 'Simpan Video Skeleton (.mp4)',
            subtitle: 'Ekspor MP4 mandiri dengan garis skeleton permanen',
            leadingIcon: ParkinIcons.cameraLegs(color: AppColors.onIceAzure),
            isLoading: _isExportingMp4,
            onPressed: _isDeleting ? null : () => unawaited(_exportSkeletonMp4()),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Hapus video rekaman lokal secara permanen',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: OutlinedButton(
                key: const Key('video_delete_button'),
                onPressed: _isDeleting || _isExportingMp4
                    ? null
                    : () => unawaited(_handleDeleteVideo()),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.alertRed, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isDeleting ? 'Menghapus Video...' : 'Hapus Video Lokal',
                  style: AppTypography.buttonLabel(
                    color: AppColors.redDarkText,
                    size: 15.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTextureSurface() {
    final opened = _opened;
    if (opened == null || opened.isSimulated || opened.textureId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pratinjau Video + Skeleton',
              style: AppTypography.captionBadge(
                color: AppColors.darkMuted,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget surface = Texture(textureId: opened.textureId!);
    if (!opened.handlesCropAndRotation && opened.rotationDegrees != 0) {
      surface = RotatedBox(
        quarterTurns: (opened.rotationDegrees ~/ 90) % 4,
        child: surface,
      );
    }
    return surface;
  }
}

class _SmallControlButton extends StatelessWidget {
  const _SmallControlButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Material(
        color: selected ? AppColors.iceSurface : AppColors.slateCanvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? AppColors.clinicalAzure
                : AppColors.subtleBorderLight,
            width: 1.5,
          ),
        ),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.captionBadge(
                    color: selected
                        ? AppColors.onIceAzure
                        : AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
