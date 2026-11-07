import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/platform/app_orientation.dart';
import 'package:proalbums/core/platform/screen_awake.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_settings.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/shared/widgets/slideshow_player.dart';

/// Viewer > More > Slideshow (like the system gallery, plain on purpose):
/// from the picture on screen onwards through the viewer's list, dark screen,
/// no bars, ~2 s each with a slow zoom and a fade. Videos show their picture.
/// The screen stays on and does not turn. A tap, Back or the end closes it
/// and the viewer shows the picture that was on screen.
class SlideshowPage extends ConsumerStatefulWidget {
  const SlideshowPage({required this.startId, super.key});

  final String startId;

  @override
  ConsumerState<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends ConsumerState<SlideshowPage> {
  /// The viewer's list, taken once (it does not change during the show).
  late final List<MediaItem> _items = ref.read(
    ref.read(viewerSessionProvider).items,
  );

  late final int _start = () {
    final index = _items.indexWhere((item) => item.id == widget.startId);
    return index < 0 ? 0 : index;
  }();

  late int _current = _start;
  bool _leaving = false;
  bool _landscape = false;

  /// The same picture (and image-cache key) the viewer shows, so pictures
  /// already seen there appear at once.
  final Map<int, ImageProvider> _images = {};

  /// Settings > Auto-rotate, read when the page opens (ref cannot be read
  /// while it closes).
  ViewerRotation? _viewerRotation;

  @override
  void initState() {
    super.initState();
    _viewerRotation = ref.read(viewerAutoRotateProvider).value;
    unawaited(ref.read(videoPlaybackProvider.notifier).pause());
    unawaited(ScreenAwake.keepOn(on: true, by: 'slideshow'));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Stays the way it is now, whatever the phone does.
      _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
      unawaited(AppOrientation.hold(landscape: _landscape));
    });
  }

  @override
  void dispose() {
    unawaited(ScreenAwake.keepOn(on: false, by: 'slideshow'));
    // Back to the viewer's rules: turns with the phone (as set in Settings),
    // status bar only in portrait.
    unawaited(applyRotation(_viewerRotation));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    super.dispose();
  }

  ImageProvider _imageAt(int offset) {
    final index = _start + offset;
    return _images.putIfAbsent(index, () {
      final media = MediaQuery.of(context);
      final ownLoader = ref.read(viewerSessionProvider).imageLoader;
      return MediaThumbnailImage(
        id: _items[index].id,
        size: viewerImageLongEdge(
          media.size.longestSide * media.devicePixelRatio,
        ),
        load:
            ownLoader ??
            (id, size) async {
              final result = await ref.read(loadDisplayImageUseCaseProvider)(
                id: id,
                maxLongEdge: size,
              );
              return result.fold((failure) => null, (bytes) => bytes);
            },
      );
    });
  }

  /// Tap, Back or the end: the viewer shows the picture on screen now.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    ref.read(viewerJumpProvider.notifier).to(_items[_current].id);
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        // Dark in every theme, like the system gallery.
        backgroundColor: AppColors.darkCanvasObsidian,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: _items.isEmpty
              ? const SizedBox.expand()
              : SlideshowPlayer(
                  // The show starts at the picture on screen: index 0 here is
                  // that picture.
                  count: _items.length - _start,
                  imageAt: _imageAt,
                  onIndex: (offset) => _current = _start + offset,
                  onFinished: _leave,
                ),
        ),
      ),
    );
  }
}
