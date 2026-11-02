import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_video_item.dart';

/// One page of the viewer.
///
/// Shows a small thumbnail at once (it is usually already cached from the
/// grid), and the screen-size picture on top of it as soon as that is ready.
class ViewerPageItem extends ConsumerStatefulWidget {
  const ViewerPageItem({
    required this.item,
    required this.onSingleTap,
    super.key,
  });

  final MediaItem item;
  final VoidCallback onSingleTap;

  @override
  ConsumerState<ViewerPageItem> createState() => _ViewerPageItemState();
}

class _ViewerPageItemState extends ConsumerState<ViewerPageItem>
    with SingleTickerProviderStateMixin {
  static const int _placeholderSize = 384;
  static const Duration _doubleTapWindow = Duration(milliseconds: 220);
  static const double _doubleTapZoom = 2.5;

  late final AnimationController _zoomController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<double>? _zoomAnimation;
  VoidCallback? _zoomListener;

  // A single tap toggles the bars, but a double tap must NOT: wait a moment
  // to see if a second tap follows.
  Timer? _tapTimer;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _zoomController.dispose();
    super.dispose();
  }

  void _onTap() {
    _tapTimer?.cancel();
    _tapTimer = Timer(_doubleTapWindow, widget.onSingleTap);
  }

  void _onDoubleTap(ExtendedImageGestureState state) {
    _tapTimer?.cancel();

    final details = state.gestureDetails;
    if (details == null) return;
    final position = state.pointerDownPosition;
    final begin = details.totalScale ?? 1.0;
    final end = begin > 1.05 ? 1.0 : _doubleTapZoom;

    final oldListener = _zoomListener;
    if (oldListener != null) _zoomAnimation?.removeListener(oldListener);
    _zoomController
      ..stop()
      ..reset();

    void listener() {
      state.handleDoubleTap(
        scale: _zoomAnimation!.value,
        doubleTapPosition: position,
      );
    }

    _zoomListener = listener;
    _zoomAnimation = _zoomController.drive(
      Tween<double>(begin: begin, end: end)
          .chain(CurveTween(curve: Curves.easeInOut)),
    )..addListener(listener);
    _zoomController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final media = MediaQuery.of(context);
    final longEdge = viewerImageLongEdge(
      media.size.longestSide * media.devicePixelRatio,
    );

    final thumbnail = MediaThumbnailImage(
      id: item.id,
      size: _placeholderSize,
      load: (id, size) async {
        final result = await ref.read(getMediaThumbnailUseCaseProvider)(
          ThumbnailRequest(id: id, size: size),
        );
        return result.fold((failure) => null, (bytes) => bytes);
      },
    );

    final picture = MediaThumbnailImage(
      id: item.id,
      size: longEdge,
      load: (id, size) async {
        final result = await ref
            .read(loadDisplayImageUseCaseProvider)(id: id, maxLongEdge: size);
        return result.fold((failure) => null, (bytes) => bytes);
      },
    );

    if (item.isVideo) {
      return ViewerVideoItem(
        item: item,
        poster: picture,
        placeholder: thumbnail,
        onSingleTap: widget.onSingleTap,
      );
    }

    // ONE layer: while the big picture loads, ExtendedImage shows the small
    // thumbnail in its place, then swaps in the picture. (Two layers on top of
    // each other showed a "duplicate" as soon as the picture was zoomed.)
    final placeholder = Image(
      image: thumbnail,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: ExtendedImage(
        // A new screen size (the phone was turned) starts the picture fresh.
        // The old zoom / position belonged to the old size and drew the picture
        // in the wrong place.
        key: ValueKey(media.size),
        image: picture,
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (state) => GestureConfig(
          minScale: 1,
          animationMinScale: 0.9,
          maxScale: 4,
          animationMaxScale: 4.5,
          inPageView: true,
        ),
        onDoubleTap: _onDoubleTap,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
            return state.completedWidget;
          }
          return placeholder;
        },
      ),
    );
  }
}
