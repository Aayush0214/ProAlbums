import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:video_player/video_player.dart';

/// One video page: its picture with a play button; once started, the video
/// itself. Tap anywhere else = show / hide the bars.
class ViewerVideoItem extends ConsumerWidget {
  const ViewerVideoItem({
    required this.item,
    required this.poster,
    required this.placeholder,
    required this.onSingleTap,
    super.key,
  });

  final MediaItem item;

  /// Screen-size picture and the small one shown while it loads.
  final ImageProvider poster;
  final ImageProvider placeholder;
  final VoidCallback onSingleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only what this page needs, so it does not rebuild for anything else.
    final view = ref.watch(
      videoPlaybackProvider.select((s) {
        final mine = s.activeId == item.id;
        return (
          controller: mine ? s.controller : null,
          status: mine ? s.status : VideoStatus.idle,
          playing: mine && s.isPlaying,
          started: mine && s.started,
          scrubbing: mine && s.isScrubbing,
          fill: s.fill,
        );
      }),
    );
    final controller = view.controller;
    // The play button shows until the video was started (even if it is
    // already prepared underneath), and again whenever it is paused.
    final showPlay =
        !view.playing &&
        !view.scrubbing &&
        !(view.started && view.status == VideoStatus.loading);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSingleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The pictures are only needed until the first video frame is on
          // screen. After that they would just be painted under the video
          // 120 times a second for nothing.
          _PosterLayers(
            controller: controller,
            poster: poster,
            placeholder: placeholder,
          ),
          if (controller != null && view.fill)
            // "Crop to fit": fills the screen, the overflow is cut off.
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: RepaintBoundary(child: VideoPlayer(controller)),
                ),
              ),
            )
          else if (controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                // Its own layer: the moving video does not make the rest of
                // the page (bars, strip) repaint, and the other way round.
                child: RepaintBoundary(child: VideoPlayer(controller)),
              ),
            ),
          if (showPlay)
            Center(
              child: Material(
                color: AppColors.mediaBadgeFill,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => ref
                      .read(videoPlaybackProvider.notifier)
                      .playOrToggle(item),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      LucideIcons.play,
                      size: 48,
                      color: AppColors.mediaBadgeText,
                    ),
                  ),
                ),
              ),
            ),
          if (view.status == VideoStatus.error)
            Align(
              alignment: const Alignment(0, 0.35),
              child: Text(
                'This video cannot be played.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The poster pictures under the video. They go away once the video is
/// really playing (its first frame is drawn), so the GPU paints one
/// full-screen layer less for every frame of the video.
class _PosterLayers extends StatefulWidget {
  const _PosterLayers({
    required this.controller,
    required this.poster,
    required this.placeholder,
  });

  final VideoPlayerController? controller;
  final ImageProvider poster;
  final ImageProvider placeholder;

  @override
  State<_PosterLayers> createState() => _PosterLayersState();
}

class _PosterLayersState extends State<_PosterLayers> {
  bool _videoShowing = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onVideo);
  }

  @override
  void didUpdateWidget(_PosterLayers old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onVideo);
      _videoShowing = false;
      widget.controller?.addListener(_onVideo);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onVideo);
    super.dispose();
  }

  void _onVideo() {
    final value = widget.controller?.value;
    if (_videoShowing || value == null) return;
    // Playing and past the very first moment = a real frame is on screen.
    if (value.isPlaying && value.position > const Duration(milliseconds: 300)) {
      widget.controller?.removeListener(_onVideo);
      setState(() => _videoShowing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videoShowing) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: widget.placeholder,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
        Image(
          image: widget.poster,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
