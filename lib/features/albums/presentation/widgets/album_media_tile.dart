import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// One picture / video of the album grid, with the favourite heart.
class AlbumMediaTile extends ConsumerWidget {
  const AlbumMediaTile({
    required this.item,
    required this.thumbnailSize,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final MediaItem item;
  final int thumbnailSize;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoriteIdsProvider.select((ids) => ids.value?.contains(item.id) ?? false),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumbnail(
            item: item,
            size: thumbnailSize,
            compactBadge: compact,
            badgeInset: isFavorite ? (compact ? 12 : 22) : 0,
          ),
          if (isFavorite)
            Positioned(
              left: compact ? 3 : 6,
              bottom: compact ? 3 : 6,
              child: Icon(
                // Filled (Lucide has no filled icons).
                Icons.favorite,
                size: compact ? 10 : 18,
                color: AppColors.mediaBadgeText,
                shadows: const [
                  Shadow(blurRadius: 4, color: AppColors.mediaBadgeFill),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
