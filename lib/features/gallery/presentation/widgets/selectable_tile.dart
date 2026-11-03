import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

/// What a tile shows about selection.
enum TileMode { normal, unselected, selected }

/// A thumbnail that opens the viewer on tap, and can be selected. (Long press
/// and drag are handled for the whole grid by DragSelectGestures.)
///
/// A plain widget on purpose: its row ([GalleryItemsRow]) watches selection
/// and hearts ONCE for all its tiles and passes the answers in. One watch per
/// tile meant 100+ Riverpod subscriptions made and closed on every zoom
/// (~6 ms of a zoom frame in the CPU profile).
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    required this.item,
    required this.thumbnailSize,
    required this.compact,
    required this.mode,
    required this.isFavorite,
    required this.load,
    required this.onTap,
    super.key,
  });

  final MediaItem item;
  final int thumbnailSize;
  final bool compact;
  final TileMode mode;
  final bool isFavorite;
  final ThumbnailLoader load;

  /// Normal mode: open the viewer. Selection mode: select / unselect.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = mode == TileMode.selected;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumbnailView(
            item: item,
            size: thumbnailSize,
            load: load,
            compactBadge: compact,
            // Heart (18 px, or 10 px when tiny) + a small gap.
            badgeInset: isFavorite ? (compact ? 12 : 22) : 0,
          ),
          if (isFavorite)
            Positioned(
              left: compact ? 3 : 6,
              bottom: compact ? 3 : 6,
              child: Icon(
                Icons.favorite_rounded,
                size: compact ? 10 : 18,
                color: AppColors.mediaBadgeText,
                shadows: const [
                  Shadow(blurRadius: 4, color: AppColors.mediaBadgeFill),
                ],
              ),
            ),
          if (selected)
            ColoredBox(
              color: context.colorScheme.primary.withValues(alpha: 0.22),
            ),
          if (mode != TileMode.normal)
            Positioned(
              top: compact ? 3 : 6,
              right: compact ? 3 : 6,
              child: SelectionCheckbox(
                state: selected ? SelectionState.all : SelectionState.none,
                size: compact ? 14 : 22,
                onPhoto: true,
              ),
            ),
        ],
      ),
    );
  }
}
