import 'package:flutter/material.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selectable_tile.dart';

/// One line of square thumbnails. Intentionally simple: a Row of fixed-size
/// boxes is the cheapest thing Flutter can lay out.
class GalleryItemsRow extends StatelessWidget {
  const GalleryItemsRow({
    required this.items,
    required this.cellSize,
    required this.thumbnailSize,
    this.compactBadge = false,
    super.key,
  });

  final List<MediaItem> items;
  final double cellSize;
  final int thumbnailSize;
  final bool compactBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GalleryGeometry.gap),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: GalleryGeometry.gap),
            SizedBox(
              width: cellSize,
              height: cellSize,
              child: SelectableTile(
                key: ValueKey(items[i].id),
                item: items[i],
                thumbnailSize: thumbnailSize,
                compact: compactBadge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
