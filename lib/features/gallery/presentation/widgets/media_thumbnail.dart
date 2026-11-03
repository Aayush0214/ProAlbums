import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';
import 'package:proalbums/core/utils/duration_format.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';

/// The thumbnail loader for [MediaThumbnailView], from the use case. A grid
/// reads it ONCE (per row), not once per tile.
ThumbnailLoader thumbnailLoader(WidgetRef ref) {
  final getThumbnail = ref.read(getMediaThumbnailUseCaseProvider);
  return (id, size) async {
    final result = await getThumbnail(ThumbnailRequest(id: id, size: size));
    return result.fold((failure) => null, (bytes) => bytes);
  };
}

/// One square tile: cached thumbnail + (for videos) a duration badge.
/// For single tiles (album covers, pickers). Grids use [MediaThumbnailView]
/// with a loader they read once, so a tile costs no Riverpod lookup.
class MediaThumbnail extends ConsumerWidget {
  const MediaThumbnail({
    required this.item,
    this.size = 256,
    this.compactBadge = false,
    this.badgeInset = 0,
    super.key,
  });

  final MediaItem item;
  final int size;
  final bool compactBadge;
  final double badgeInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaThumbnailView(
        item: item,
        size: size,
        compactBadge: compactBadge,
        badgeInset: badgeInset,
        load: thumbnailLoader(ref),
      );
}

/// The tile itself: plain widget, the loader comes from outside.
class MediaThumbnailView extends StatelessWidget {
  const MediaThumbnailView({
    required this.item,
    required this.load,
    this.size = 256,
    this.compactBadge = false,
    this.badgeInset = 0,
    this.showVideoBadge = true,
    super.key,
  });

  final MediaItem item;

  /// Fetches the JPEG bytes. Not part of the image cache key.
  final ThumbnailLoader load;

  /// Square side in pixels. The grid picks it from the cell size.
  final int size;

  /// Tiny tiles (overview zoom) show only a camera icon instead of the
  /// duration, because the text would not fit.
  final bool compactBadge;

  /// Pushes the video badge to the right, to make room for the favourite
  /// heart that sits in the same corner (like the system gallery).
  final double badgeInset;

  /// false when the tile shows its own label in that corner.
  final bool showVideoBadge;

  @override
  Widget build(BuildContext context) {
    // After a zoom the tile wants a new size. A copy that is already decoded
    // is used instead of decoding (and uploading to the GPU) again:
    //  - same size or bigger: drawn as it is (zoom out costs nothing),
    //  - only smaller: shown while the right size loads (zoom in is never
    //    an empty tile).
    final ready = MediaThumbnailImage.readyAtLeast(item.id, size, load);
    final placeholder = ready == null
        ? MediaThumbnailImage.readyBelow(item.id, size, load)
        : null;

    return ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ready ?? MediaThumbnailImage(id: item.id, size: size, load: load),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            // No fade-in: measured, it cost ~9 points of slow frames while
            // scrolling (every fading tile needs its own transparency layer).
            frameBuilder: placeholder == null
                ? null
                : (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null
                        ? Image(
                            image: placeholder,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                          )
                        : child,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          if (item.isVideo && showVideoBadge)
            Positioned(
              left: (compactBadge ? 3 : 6) + badgeInset,
              bottom: compactBadge ? 3 : 6,
              child: _VideoBadge(duration: item.duration, compact: compactBadge),
            ),
        ],
      ),
    );
  }
}

/// Stitch style pill: play icon + duration (or just a camera icon when tiny).
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.duration, required this.compact});

  final Duration duration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mediaBadgeFill,
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.all(2)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: compact
            ? const Icon(
                LucideIcons.video,
                size: 11,
                color: AppColors.mediaBadgeText,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.play,
                    size: 12,
                    color: AppColors.mediaBadgeText,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    formatVideoDuration(duration),
                    style: AppTypography.badgeTimestamp(),
                  ),
                ],
              ),
      ),
    );
  }
}
