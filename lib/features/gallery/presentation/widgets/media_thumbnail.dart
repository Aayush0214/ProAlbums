import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';
import 'package:proalbums/core/utils/duration_format.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';

/// One square tile: cached thumbnail + (for videos) a duration badge.
class MediaThumbnail extends ConsumerWidget {
  const MediaThumbnail({
    required this.item,
    this.size = 256,
    this.compactBadge = false,
    super.key,
  });

  final MediaItem item;

  /// Square side in pixels. The grid picks it from the cell size.
  final int size;

  /// Tiny tiles (overview zoom) show only a camera icon instead of the
  /// duration, because the text would not fit.
  final bool compactBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getThumbnail = ref.watch(getMediaThumbnailUseCaseProvider);

    return ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: MediaThumbnailImage(
              id: item.id,
              size: size,
              load: (id, size) async {
                final result = await getThumbnail(
                  ThumbnailRequest(id: id, size: size),
                );
                return result.fold((failure) => null, (bytes) => bytes);
              },
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            // No fade-in: measured, it cost ~9 points of slow frames while
            // scrolling (every fading tile needs its own transparency layer).
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          if (item.isVideo)
            Positioned(
              left: compactBadge ? 3 : 6,
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
                Icons.videocam_rounded,
                size: 11,
                color: AppColors.mediaBadgeText,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
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
