import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

enum _TileMode { normal, unselected, selected }

/// A thumbnail that can be selected: tap toggles while selecting. (Long press
/// and drag are handled for the whole grid by DragSelectGestures.)
///
/// Each tile watches ONLY its own state (normal / unselected / selected), so
/// selecting one photo rebuilds one tile, not the whole grid.
class SelectableTile extends ConsumerWidget {
  const SelectableTile({
    required this.item,
    required this.thumbnailSize,
    required this.compact,
    super.key,
  });

  final MediaItem item;
  final int thumbnailSize;
  final bool compact;

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
    final controller = ref.read(photosSelectionControllerProvider.notifier);
    final selected = mode == _TileMode.selected;

    return GestureDetector(
      onTap: mode == _TileMode.normal ? null : () => controller.toggle(item.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumbnail(
            item: item,
            size: thumbnailSize,
            compactBadge: compact,
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
