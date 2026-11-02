import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/core/platform/app_orientation.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_bottom_bar.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_filmstrip.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_info_card.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_page_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_top_bar.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';

/// Full-screen viewer: swipe between photos, pinch / double tap to zoom, tap to
/// hide the bars. Pages follow the order of the Photos tab.
class MediaViewerPage extends ConsumerStatefulWidget {
  const MediaViewerPage({
    required this.initialId,
    required this.items,
    super.key,
  });

  final String initialId;

  /// The list to swipe through (see openMediaViewer).
  final ProviderListenable<List<MediaItem>> items;

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage>
    with WidgetsBindingObserver {
  ExtendedPageController? _pageController;
  int _index = 0;
  String? _currentId;
  bool _chromeVisible = true;

  // The Info card floating over the picture.
  bool _infoVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only the viewer may turn sideways (the rest of the app is portrait).
    AppOrientation.allowRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleVideoPrepare());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prepareTimer?.cancel();
    _pageController?.dispose();
    // Back to the app's normal look (see main.dart).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppOrientation.lockPortrait();
    super.dispose();
  }

  // When the person rests on a video for a moment, its player is made ready in
  // the background (not played), so the play button starts it at once. Quickly
  // swiping past videos prepares none of them.
  Timer? _prepareTimer;

  void _scheduleVideoPrepare() {
    _prepareTimer?.cancel();
    _prepareTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final list = ref.read(widget.items);
      if (_index >= list.length) return;
      final item = list[_index];
      if (item.isVideo) ref.read(videoPlaybackProvider.notifier).prepare(item);
    });
  }

  // The app goes to the background: a video must not keep playing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(videoPlaybackProvider.notifier).pause();
    }
  }

  void _selectFromStrip(int index) {
    final list = ref.read(widget.items);
    if (index < 0 || index >= list.length || index == _index) return;
    setState(() {
      _index = index;
      _currentId = list[index].id;
    });
    ref.read(videoPlaybackProvider.notifier).close();
    _scheduleVideoPrepare();
    _pageController?.jumpToPage(index);
  }

  bool _landscape = false;

  /// Delete the photo / video on screen. A playing video is paused first. When
  /// it is in the trash, the list shrinks and the viewer lands on the
  /// neighbour by itself (see the "list changed" branch in build).
  Future<void> _delete(MediaItem item) async {
    unawaited(ref.read(videoPlaybackProvider.notifier).pause());
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    await deleteMediaItems(
      context,
      ref,
      [item],
      // filmstrip 68 + bottom bar 64 (portrait only) + safe area
      snackBarBottomInset: 68 + (landscape ? 0 : 64) + safeBottom,
    );
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    _applySystemUi();
  }

  /// Portrait: the status bar shows with the bars. Landscape: always hidden
  /// (like the system gallery) so the top bar sits at the very top.
  void _applySystemUi() {
    final show = _chromeVisible && !_landscape;
    SystemChrome.setEnabledSystemUIMode(
      show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(widget.items);

    if (items.isEmpty) {
      // Nothing left to show (the last photo was deleted).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }

    if (_pageController == null) {
      final start = resolveViewerIndex(
        ids: [for (final item in items) item.id],
        currentId: widget.initialId,
        lastIndex: 0,
      );
      _index = start;
      _currentId = items[start].id;
      _pageController = ExtendedPageController(initialPage: start);
    } else if (_index >= items.length || items[_index].id != _currentId) {
      // The list changed under us (new photo, deletion): keep the same photo.
      final resolved = resolveViewerIndex(
        ids: [for (final item in items) item.id],
        currentId: _currentId,
        lastIndex: _index,
      );
      _index = resolved;
      _currentId = items[resolved].id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(videoPlaybackProvider).activeId != _currentId) {
          ref.read(videoPlaybackProvider.notifier).close();
        }
        if (_pageController!.hasClients) _pageController!.jumpToPage(resolved);
        _scheduleVideoPrepare();
      });
    }

    final current = items[_index];
    final playback = ref.watch(
      videoPlaybackProvider.select(
        (s) => (
          activeId: s.activeId,
          status: s.status,
          started: s.started,
          playing: s.isPlaying,
        ),
      ),
    );
    final videoReady = current.isVideo &&
        playback.activeId == current.id &&
        playback.status == VideoStatus.ready &&
        playback.started;
    final videoPlaying = videoReady && playback.playing;
    void playPause() =>
        ref.read(videoPlaybackProvider.notifier).playOrToggle(current);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape != _landscape) {
      _landscape = landscape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySystemUi();
      });
    }

    // The viewer follows the app theme (light or dark), like the system
    // gallery. The status bar icons follow it too.
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle ??
            (context.isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark),
        child: Stack(
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (index) {
                final list = ref.read(widget.items);
                if (index >= list.length) return;
                setState(() {
                  _index = index;
                  _currentId = list[index].id;
                });
                // Another page: its video (if any) starts only when asked.
                ref.read(videoPlaybackProvider.notifier).close();
                _scheduleVideoPrepare();
                if (_infoVisible) setState(() => _infoVisible = false);
              },
              itemBuilder: (context, index) => ViewerPageItem(
                key: ValueKey(items[index].id),
                item: items[index],
                onSingleTap: _toggleChrome,
              ),
            ),
            // Tap outside the Info card closes it.
            if (_infoVisible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _infoVisible = false),
                ),
              ),
            _FadingBar(
              visible: _chromeVisible,
              alignment: Alignment.topCenter,
              child: ViewerTopBar(
                item: current,
                showActions: landscape,
                infoActive: _infoVisible,
                onInfo: () => setState(() => _infoVisible = !_infoVisible),
                onDelete: () => _delete(current),
              ),
            ),
            _FadingBar(
              visible: _chromeVisible,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Neighbours before and after; a playing video opens up into
                  // its own frames inside this same strip.
                  RepaintBoundary(
                    child: ViewerFilmstrip(
                      items: items,
                      currentIndex: _index,
                      onSelect: _selectFromStrip,
                    ),
                  ),
                  // Landscape: the actions are in the top bar instead.
                  if (!landscape)
                    ViewerBottomBar(
                      item: current,
                      isPlaying: videoPlaying,
                      onPlayPause: playPause,
                      onDelete: () => _delete(current),
                    ),
                ],
              ),
            ),
            // Landscape: the play / pause button sits in the corner of the
            // video, above the strip.
            if (landscape && videoReady)
              _FadingBar(
                visible: _chromeVisible,
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 68 + 12),
                  child: Material(
                    color: AppColors.mediaBadgeFill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: playPause,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          videoPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                          color: AppColors.mediaBadgeText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_infoVisible)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      kToolbarHeight + (landscape ? 4 : 12),
                      20,
                      0,
                    ),
                    child: SingleChildScrollView(
                      child: ViewerInfoCard(item: current),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A bar that fades out (and stops catching touches) when hidden.
class _FadingBar extends StatelessWidget {
  const _FadingBar({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}
