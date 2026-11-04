import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/features/compress/presentation/compress_providers.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selectable_tile.dart';

/// "Not selecting" in the selection mask.
const int _notSelecting = -1;

/// Bit i is set when item i of [items] is in [ids].
int rowMask(List<MediaItem> items, Set<String> ids) {
  var mask = 0;
  for (var i = 0; i < items.length; i++) {
    if (ids.contains(items[i].id)) mask |= 1 << i;
  }
  return mask;
}

/// One line of square thumbnails. Intentionally simple: a Row of fixed-size
/// boxes is the cheapest thing Flutter can lay out.
///
/// The ROW (not each tile) watches selection and hearts, as one small number
/// each (a bit per tile). A row rebuilds only when one of ITS tiles changes,
/// and a zoom makes ~20 subscriptions instead of 200+.
class GalleryItemsRow extends ConsumerWidget {
  const GalleryItemsRow({
    required this.items,
    required this.cellSize,
    required this.thumbnailSize,
    this.compactBadge = false,
    this.viewerItems,
    super.key,
  });

  final List<MediaItem> items;
  final double cellSize;
  final int thumbnailSize;
  final bool compactBadge;

  /// The list the viewer swipes through when a tile is tapped. null = the
  /// Photos tab list; an album (or search...) passes its own.
  final ProviderListenable<List<MediaItem>>? viewerItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = MediaScope.of(context);
    // A "choose many" picker always shows its checkboxes.
    final alwaysSelecting = scope.pickMode == PickMode.multi;
    final selection = ref.watch(
      mediaSelectionControllerProvider(scope.id).select(
        (s) =>
            s.active || alwaysSelecting ? rowMask(items, s.ids) : _notSelecting,
      ),
    );
    final hearts = ref.watch(
      favoriteIdsProvider.select((ids) {
        final set = ids.value;
        return set == null ? 0 : rowMask(items, set);
      }),
    );
    // Copies made by Compress size (videos): a bit per tile, like hearts.
    final compressed = ref.watch(
      compressedSizesProvider.select((sizes) {
        final map = sizes.value;
        if (map == null || map.isEmpty) return 0;
        var mask = 0;
        for (var i = 0; i < items.length; i++) {
          if (map.containsKey(items[i].id)) mask |= 1 << i;
        }
        return mask;
      }),
    );
    final compressedSizes = compressed == 0
        ? null
        : ref.read(compressedSizesProvider).value;
    final controller = ref.read(
      mediaSelectionControllerProvider(scope.id).notifier,
    );
    final load = scope.thumbnailLoader ?? thumbnailLoader(ref);
    final selecting = selection != _notSelecting;
    final onOpen = scope.onOpen;

    VoidCallback onTapOf(MediaItem item) => switch (scope.pickMode) {
      // Choose ONE: tapping it is the choice.
      PickMode.single => () => scope.onPick!(item),
      // Choose many: select / unselect (startWith also turns the
      // picker's selection on the first time).
      PickMode.multi => () => controller.startWith(item.id),
      PickMode.none =>
        selecting
            ? () => controller.toggle(item.id)
            : onOpen != null
            ? () => onOpen(item)
            : () => openMediaViewer(
                context,
                ref,
                id: item.id,
                items: viewerItems,
              ),
    };

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
                mode: !selecting
                    ? TileMode.normal
                    : (selection & (1 << i)) != 0
                    ? TileMode.selected
                    : TileMode.unselected,
                isFavorite: (hearts & (1 << i)) != 0,
                compressedBytes:
                    (compressed & (1 << i)) != 0 && items[i].isVideo
                    ? (compressedSizes?[items[i].id])
                    : null,
                label: scope.tileLabel?.call(items[i]),
                load: load,
                onTap: onTapOf(items[i]),
                // Selecting: ⤢ still opens the viewer (not a one-tap picker).
                onExpand: selecting && scope.pickMode != PickMode.single
                    ? () => openMediaViewer(
                        context,
                        ref,
                        id: items[i].id,
                        items: viewerItems,
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
