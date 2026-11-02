import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// The last tile of "More albums": the pictures of two of the hidden albums
/// side by side, "Other albums" and how many albums are inside.
class OtherAlbumsTile extends StatelessWidget {
  const OtherAlbumsTile({required this.albums, required this.onTap, super.key});

  final List<Album> albums;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final covers = [
      for (final album in albums)
        if (album.cover != null) album.cover!,
    ].take(2).toList();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: covers.isEmpty
                  ? ColoredBox(
                      color: context.colorScheme.surfaceContainerHigh,
                      child: Icon(
                        LucideIcons.image,
                        color: context.colors.textSecondary,
                      ),
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < covers.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            child: MediaThumbnail(item: covers[i], size: 256),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Other albums',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium,
          ),
          Text(
            NumberFormat.decimalPattern().format(albums.length),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
