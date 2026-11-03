import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
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
    this.label,
    super.key,
  });

  final MediaItem item;
  final int thumbnailSize;
  final bool compact;
  final TileMode mode;
  final bool isFavorite;
  final ThumbnailLoader load;

  /// A small text in the bottom corner (e.g. "29 days"), shown instead of
  /// the video badge. null = none.
  final String? label;

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
            showVideoBadge: label == null,
            // Heart (18 px, or 10 px when tiny) + a small gap.
            badgeInset: isFavorite ? (compact ? 12 : 22) : 0,
          ),
          if (label case final text?)
            Positioned(
              left: compact ? 3 : 6,
              bottom: compact ? 3 : 6,
              child: _LabelBadge(text: text, compact: compact),
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

/// The small pill of [SelectableTile.label], in the video badge's style.
class _LabelBadge extends StatelessWidget {
  const _LabelBadge({required this.text, required this.compact});

  final String text;
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
            ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text, style: AppTypography.badgeTimestamp()),
      ),
    );
  }
}
