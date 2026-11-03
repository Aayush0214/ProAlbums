import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/filmstrip_layout.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_video_frames.dart';

/// The row of small pictures under the photo / video.
///
/// - Photos: neighbours before and after, the current one bigger. Tap to jump,
///   slide to scrub through the library.
/// - A PLAYING video opens up in the same row into all its frames (the line in
///   the middle is "now"). Sliding over it moves through the video; sliding
///   past its ends goes on to the neighbouring items.
class ViewerFilmstrip extends ConsumerStatefulWidget {
  const ViewerFilmstrip({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<MediaItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<ViewerFilmstrip> createState() => _ViewerFilmstripState();
}

class _ViewerFilmstripState extends ConsumerState<ViewerFilmstrip>
    with SingleTickerProviderStateMixin {
  static const double _height = 68;
  static const int _thumbnailSize = 96;
  static const int _maxPreloadedFrames = 80;

  // Start the background frames only after the video is running smoothly.
  // `--dart-define=VIDEO_PRELOAD=false` turns the preloading off, to compare.
  static const bool _preloadEnabled = bool.fromEnvironment(
    'VIDEO_PRELOAD',
    defaultValue: true,
  );
  static const Duration _preloadDelay = Duration(milliseconds: 2000);

  late final ScrollController _controller;
  final ValueNotifier<Duration?> _scrubTime = ValueNotifier<Duration?>(null);
  late final Ticker _ticker;

  FilmstripLayout _layout = const FilmstripLayout(itemCount: 0);
  Duration _videoDuration = Duration.zero;

  // From the moment the finger touches the strip until it lets go.
  bool _dragging = false;
  double _lastTickOffset = -1;
  int _preloadToken = 0;

  @override
  void initState() {
    super.initState();
    _layout = _layoutFor(ref.read(videoPlaybackProvider));
    _controller = ScrollController(initialScrollOffset: _targetOffset());
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void dispose() {
    _preloadToken++;
    _ticker.dispose();
    _controller.dispose();
    _scrubTime.dispose();
    super.dispose();
  }

  FilmstripLayout _layoutFor(VideoPlaybackState playback) {
    final count = widget.items.length;
    final index = widget.currentIndex;
    if (count == 0 || index >= count) return FilmstripLayout(itemCount: count);
    final current = widget.items[index];
    final open =
        current.isVideo &&
        playback.activeId == current.id &&
        playback.status == VideoStatus.ready &&
        playback.started &&
        playback.duration > Duration.zero;
    _videoDuration = open ? playback.duration : Duration.zero;
    return FilmstripLayout(
      itemCount: count,
      videoIndex: open ? index : null,
      frameCount: open ? videoFrameCount(playback.duration) : 0,
    );
  }

  /// Where the strip should rest right now.
  double _targetOffset() {
    if (_layout.expanded) {
      final position = ref
          .read(videoPlaybackProvider.notifier)
          .estimatedPosition();
      return _layout.offsetForVideoFraction(
        position.inMilliseconds / _videoDuration.inMilliseconds,
      );
    }
    return _layout.offsetForIndex(widget.currentIndex);
  }

  @override
  void didUpdateWidget(ViewerFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another picture became the current one (swipe in the viewer, a tap...):
    // bring it to the middle. (While the finger is on the strip the strip
    // already is where the finger wants it.)
    if (!_dragging &&
        oldWidget.currentIndex != widget.currentIndex &&
        !_layout.expanded &&
        _controller.hasClients) {
      final target = _layout.offsetForIndex(widget.currentIndex);
      final far = (target - _controller.offset).abs() > kFilmstripSlot * 12;
      if (far) {
        _controller.jumpTo(target);
      } else {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // Every screen frame: while a video plays, the strip follows it.
  void _onFrame(Duration _) {
    if (!_layout.expanded || _dragging || !_controller.hasClients) return;
    final offset = _targetOffset();
    if ((offset - _lastTickOffset).abs() < 0.05) return;
    _lastTickOffset = offset;
    _controller.jumpTo(offset.clamp(0.0, _controller.position.maxScrollExtent));
  }

  // The video was opened or closed: the strip changed shape, so the old
  // scroll offset means something else now.
  void _onShapeChanged() {
    _lastTickOffset = -1;
    _preloadToken++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      _controller.jumpTo(_targetOffset().clamp(0.0, max));
    });
    if (_layout.expanded && _preloadEnabled) {
      unawaited(_preload(_preloadToken, widget.items[widget.currentIndex].id));
    }
  }

  // Taking frames out of a video is slow, so while the strip is open they are
  // prepared in the background, nearest to "now" first. The tiles then find
  // them ready.
  Future<void> _preload(int token, String id) async {
    await Future<void>.delayed(_preloadDelay);
    if (!mounted || token != _preloadToken) return;
    final playback = ref.read(videoPlaybackProvider.notifier);
    final count = _layout.frameCount;
    final duration = _videoDuration;
    final nowIndex =
        (ref
                    .read(videoPlaybackProvider.notifier)
                    .estimatedPosition()
                    .inMilliseconds /
                duration.inMilliseconds *
                count)
            .floor()
            .clamp(0, count - 1);
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) => (a - nowIndex).abs().compareTo((b - nowIndex).abs()));

    for (final index in order.take(_maxPreloadedFrames)) {
      if (!mounted || token != _preloadToken) return;
      await playback.waitForQuiet();
      if (!mounted || token != _preloadToken) return;
      await ref.read(getVideoFrameUseCaseProvider)(
        id: id,
        position: videoFrameTime(
          index: index,
          frameCount: count,
          duration: duration,
        ),
        size: VideoFrameTile.frameSize,
      );
      // A short rest between frames: the video's own decoding comes first.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final playback = ref.read(videoPlaybackProvider.notifier);

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      if (_layout.expanded) playback.beginScrub();
    } else if (notification is ScrollUpdateNotification && _dragging) {
      final point = _layout.pointAt(_controller.offset);
      final fraction = point.videoFraction;
      if (_layout.expanded && fraction != null) {
        // On the video: move through it.
        final position = Duration(
          milliseconds: (fraction * _videoDuration.inMilliseconds).round(),
        );
        _scrubTime.value = position;
        playback.scrubTo(position);
      } else {
        // Off the video (or no video): another item.
        _scrubTime.value = null;
        if (point.index != widget.currentIndex) widget.onSelect(point.index);
      }
    } else if (notification is ScrollEndNotification && _dragging) {
      _dragging = false;
      _lastTickOffset = -1;
      _scrubTime.value = null;
      if (_layout.expanded) {
        playback.endScrub(); // plays on from here if it was playing
      } else {
        // Settle with the chosen picture exactly in the middle.
        final index = _layout.pointAt(_controller.offset).index;
        _controller.animateTo(
          _layout.offsetForIndex(index),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      }
    }
    return false;
  }

  ImageProvider _thumbnailOf(MediaItem item) => MediaThumbnailImage(
    id: item.id,
    size: _thumbnailSize,
    // The screen's own loader (trash), else the normal one.
    load:
        ref.read(viewerSessionProvider).imageLoader ??
        (id, size) async {
          final result = await ref.read(getMediaThumbnailUseCaseProvider)(
            ThumbnailRequest(id: id, size: size),
          );
          return result.fold((failure) => null, (bytes) => bytes);
        },
  );

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the video starts, stops or learns its length.
    ref.watch(
      videoPlaybackProvider.select(
        (s) => (
          id: s.activeId,
          status: s.status,
          started: s.started,
          duration: s.duration,
        ),
      ),
    );

    final before = _layout;
    _layout = _layoutFor(ref.read(videoPlaybackProvider));
    if (before.expanded != _layout.expanded ||
        before.frameCount != _layout.frameCount) {
      _onShapeChanged();
    }

    final layout = _layout;
    final current = widget.items.isEmpty
        ? null
        : widget.items[widget.currentIndex];

    return ColoredBox(
      color: context.colorScheme.surface,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Equal space on both sides, so even the first and the last item
            // can reach the middle.
            final sidePadding = (constraints.maxWidth - kFilmstripSlot) / 2;

            return Stack(
              alignment: Alignment.center,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    // While a video is open, lifting the finger stops the strip
                    // at once (a fling would keep seeking and delay playing).
                    physics: layout.expanded ? const _NoFlingPhysics() : null,
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    itemExtentBuilder: (cell, dimensions) =>
                        layout.extentOfCell(cell),
                    itemCount: layout.cellCount,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, cell) {
                      final at = layout.cellAt(cell);
                      final frame = at.frame;
                      if (frame != null && current != null) {
                        return Center(
                          child: VideoFrameTile(
                            id: current.id,
                            position: videoFrameTime(
                              index: frame,
                              frameCount: layout.frameCount,
                              duration: _videoDuration,
                            ),
                            placeholder: _thumbnailOf(current),
                          ),
                        );
                      }
                      return _itemCell(at.item!);
                    },
                  ),
                ),
                if (layout.expanded)
                  // "Now": the thin white line in the middle.
                  IgnorePointer(
                    child: Container(
                      width: 2,
                      height: kVideoFrameHeight + 8,
                      decoration: BoxDecoration(
                        color: context.colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<Duration?>(
                      valueListenable: _scrubTime,
                      builder: (context, time, _) => time == null
                          ? const SizedBox.shrink()
                          : ScrubTimeBubble(time: time, total: _videoDuration),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemCell(int index) {
    final isCurrent = index == widget.currentIndex;
    final expanded = _layout.expanded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(index),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: isCurrent && !expanded
              ? kFilmstripSlot - 2
              : kFilmstripSlot - 6,
          height: isCurrent && !expanded ? 56 : 42,
          decoration: BoxDecoration(
            border: isCurrent && !expanded
                ? Border.all(color: context.colorScheme.onSurface, width: 2)
                : null,
          ),
          child: Image(
            image: _thumbnailOf(widget.items[index]),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: context.colorScheme.surfaceContainerHigh),
          ),
        ),
      ),
    );
  }
}

/// Like the normal strip, but with NO coasting after the finger lifts.
class _NoFlingPhysics extends ClampingScrollPhysics {
  const _NoFlingPhysics({super.parent});

  @override
  _NoFlingPhysics applyTo(ScrollPhysics? ancestor) =>
      _NoFlingPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Inside the strip: stop right here. (Out of range: let the normal rule
    // bring it back.)
    if (!position.outOfRange) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
