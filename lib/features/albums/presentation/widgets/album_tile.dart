import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// One album of the Albums tab: a rounded picture, the name, the count.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    required this.album,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final Album album;
  final VoidCallback onTap;

  /// Starts the select mode (long press).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cover = album.cover;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: cover == null
                  ? ColoredBox(
                      color: context.colorScheme.surfaceContainerHigh,
                      child: Icon(
                        LucideIcons.image,
                        color: context.colors.textSecondary,
                      ),
                    )
                  : MediaThumbnail(item: cover, size: 320),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium,
          ),
          Text(
            NumberFormat.decimalPattern().format(album.count),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Grey boxes in the shape of the album tiles, shown while the albums load
/// (instead of a spinner).
class AlbumTileSkeleton extends StatelessWidget {
  const AlbumTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.surfaceContainerHigh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const SizedBox(height: 12),
          ),
        ),
      ],
    );
  }
}
