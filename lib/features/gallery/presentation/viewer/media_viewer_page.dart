import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/platform/app_orientation.dart';
import 'package:proalbums/core/platform/screen_awake.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_settings.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_player_page.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_bottom_bar.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_filmstrip.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_info_card.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_page_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_text_button.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_top_bar.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';

/// Full-screen viewer: swipe between photos, pinch / double tap to zoom, tap to
/// hide the bars. Pages follow the order of the Photos tab.
class MediaViewerPage extends ConsumerStatefulWidget {
  const MediaViewerPage({required this.initialId, super.key});

  final String initialId;

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage>
    with WidgetsBindingObserver {
  /// The list to swipe through (see ViewerSession / openMediaViewer). Taken
  /// once: it does not change while this viewer is open.
  late final ProviderListenable<List<MediaItem>> _items = ref
      .read(viewerSessionProvider)
      .items;

  ExtendedPageController? _pageController;
  int _index = 0;
  String? _currentId;
  bool _chromeVisible = true;

  // The Info card floating over the picture.
  bool _infoVisible = false;

  /// The [T] button is on: text in the picture is highlighted (off again
  /// on another page).
  bool _textOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only the viewer may turn sideways (the rest of the app is portrait),
    // and only when Settings > Auto-rotate says Always.
    unawaited(applyViewerRotation(ref));
    // Settings > Keep screen on while viewing.
    ref.listenManual(viewerKeepScreenOnProvider, (_, next) {
      unawaited(ScreenAwake.keepOn(on: next.value ?? false, by: _screenHolder));
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleVideoPrepare(),
    );
  }

  static const String _screenHolder = 'viewer';

  @override
  void dispose() {
    unawaited(ScreenAwake.keepOn(on: false, by: _screenHolder));
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
      final list = ref.read(_items);
      if (_index >= list.length) return;
      final item = list[_index];
      if (!item.isVideo) return;
      final player = ref.read(videoPlaybackProvider.notifier);
      // Settings > Autoplay Videos: it starts by itself, muted.
      final autoplay = ref.read(viewerAutoplayProvider).value ?? false;
      unawaited(autoplay ? player.autoplay(item) : player.prepare(item));
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
    final list = ref.read(_items);
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

  // --- video player -----------------------------------------------------------

  /// The full-screen video player (VideoPlayerPage) over this viewer, with the
  /// same player. [rotate]: the floating rotate button turns the screen first.
  Future<void> _openPlayer(MediaItem item, {bool rotate = false}) async {
    if (!item.isVideo) return;
    if (rotate) {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      unawaited(AppOrientation.hold(landscape: !landscape));
    }
    setState(() => _infoVisible = false);
    final VideoPlayerRequest request = (item: item, rotated: rotate);
    await context.push<void>(AppRoutes.videoPlayer, extra: request);
    // Back here: the player set the system bars its own way.
    if (mounted) _applySystemUi();
  }

  /// Look only (the pages of a PDF being made) with no button from the
  /// opener: no action bar at all.
  late final bool _noBar = () {
    final session = ref.read(viewerSessionProvider);
    final own = viewerBarActionsFor(session.mediaContext);
    return (own?.isEmpty ?? false) && session.extraActions.isEmpty;
  }();

  /// Delete the photo / video on screen. A playing video is paused first. When
  /// it is in the trash, the list shrinks and the viewer lands on the
  /// neighbour by itself (see the "list changed" branch in build).
  Future<void> _delete(MediaItem item) async {
    unawaited(ref.read(videoPlaybackProvider.notifier).pause());
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
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
    // The video player is on top: it decides the system bars.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final show = _chromeVisible && !_landscape;
    SystemChrome.setEnabledSystemUIMode(
      show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_items);

    if (items.isEmpty) {
      // Nothing left to show (the last photo was deleted).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return const Scaffold();
    }

    // An action made a new item from this one (Compress size): go to it once
    // the library has it.
    final jump = ref.watch(viewerJumpProvider);
    if (jump != null &&
        _pageController != null &&
        items.any((item) => item.id == jump)) {
      _currentId = jump;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(viewerJumpProvider.notifier).clear();
      });
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
    final videoReady =
        current.isVideo &&
        playback.activeId == current.id &&
        playback.status == VideoStatus.ready &&
        playback.started;
    final videoPlaying = videoReady && playback.playing;
    void playPause() =>
        ref.read(videoPlaybackProvider.notifier).playOrToggle(current);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
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
        value:
            Theme.of(context).appBarTheme.systemOverlayStyle ??
            (context.isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark),
        child: Stack(
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (index) {
                final list = ref.read(_items);
                if (index >= list.length) return;
                setState(() {
                  _index = index;
                  _currentId = list[index].id;
                  _textOn = false;
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
                showText: _textOn && items[index].id == current.id,
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
                onTools: () => _openPlayer(current),
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
                  // Landscape: the actions are in the top bar instead. A
                  // preview (look only) may have no bar.
                  if (!landscape && !_noBar)
                    ViewerBottomBar(
                      item: current,
                      isPlaying: videoPlaying,
                      onPlayPause: playPause,
                      onDelete: () => _delete(current),
                    ),
                ],
              ),
            ),
            // A video: the rotate button floats at the right, above the
            // strip; it turns the screen and opens the video player.
            if (current.isVideo)
              _FadingBar(
                visible: _chromeVisible,
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 16,
                    bottom:
                        68 +
                        (landscape || _noBar ? 0 : 64) +
                        12 +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Material(
                    color: AppColors.mediaBadgeFill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openPlayer(current, rotate: true),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          LucideIcons.rotateCwSquare,
                          size: 22,
                          color: AppColors.mediaBadgeText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // A picture with text: [T] at the right, above the strip; it
            // highlights every line of text.
            if (!current.isVideo)
              _FadingBar(
                visible: _chromeVisible,
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 16,
                    bottom:
                        68 +
                        (landscape || _noBar ? 0 : 64) +
                        12 +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: ViewerTextButton(
                    item: current,
                    on: _textOn,
                    onTap: () => setState(() => _textOn = !_textOn),
                  ),
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
                          videoPlaying ? LucideIcons.pause : LucideIcons.play,
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
