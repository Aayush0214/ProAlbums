import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

enum _TileMode { normal, unselected, selected }

/// A thumbnail that opens the viewer on tap, and can be selected. (Long press
/// and drag are handled for the whole grid by DragSelectGestures.)
///
/// Each tile watches ONLY its own state (normal / unselected / selected), so
/// selecting one photo rebuilds one tile, not the whole grid.
class SelectableTile extends ConsumerWidget {
  const SelectableTile({
    required this.item,
    required this.thumbnailSize,
    required this.compact,
    this.items,
    this.onLongPress,
    super.key,
  });

  final MediaItem item;
  final int thumbnailSize;
  final bool compact;

  /// The list the viewer swipes through. null = the Photos tab list; an album
  /// passes its own list.
  final ProviderListenable<List<MediaItem>>? items;

  /// null = the grid handles long press itself (Photos tab: drag select).
  /// An album passes "start selecting with this item".
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      photosSelectionControllerProvider.select(
        (s) => !s.active
            ? _TileMode.normal
            : s.ids.contains(item.id)
                ? _TileMode.selected
                : _TileMode.unselected,
      ),
    );
    // Only this tile rebuilds when ITS heart changes.
    final isFavorite = ref.watch(
      favoriteIdsProvider.select((ids) => ids.value?.contains(item.id) ?? false),
    );
    final controller = ref.read(photosSelectionControllerProvider.notifier);
    final selected = mode == _TileMode.selected;

    return GestureDetector(
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onLongPress!();
            },
      // Normal mode: open the viewer. Selection mode: select / unselect.
      onTap: mode == _TileMode.normal
          ? () => openMediaViewer(
              context,
              id: item.id,
              items: items ?? photosDisplayItemsProvider,
            )
          : () => controller.toggle(item.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumbnail(
            item: item,
            size: thumbnailSize,
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
                shadows: const [Shadow(blurRadius: 4, color: AppColors.mediaBadgeFill)],
              ),
            ),
          if (selected)
            ColoredBox(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            ),
          if (mode != _TileMode.normal)
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
