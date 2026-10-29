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
/// Phase 2's grid reuses this widget as it is.
class MediaThumbnail extends ConsumerWidget {
  const MediaThumbnail({required this.item, this.size = 256, super.key});

  final MediaItem item;

  /// Square side in pixels. Phase 2 picks it from the grid cell size.
  final int size;

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
            // Fade in only when the image was NOT already in the cache, so
            // cached tiles appear instantly and new ones appear smoothly.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          if (item.isVideo)
            Positioned(
              left: 6,
              bottom: 6,
              child: _VideoBadge(duration: item.duration),
            ),
        ],
      ),
    );
  }
}

/// Stitch style pill: play icon + duration. Delete the Icon and SizedBox
/// below if you want the duration alone.
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mediaBadgeFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
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
