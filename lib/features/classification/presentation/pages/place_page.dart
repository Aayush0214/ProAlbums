import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// One place's pictures (Location > a place), like an album: the SHARED
/// grid (fixed 4 columns, no date headers, like the system gallery), the
/// shared viewer, the album's select bar.
class PlacePage extends ConsumerStatefulWidget {
  const PlacePage({required this.name, super.key});

  final String name;

  @override
  ConsumerState<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends ConsumerState<PlacePage> {
  final ScrollController _scroll = ScrollController();

  String get _scopeId => placeAlbumId(widget.name);

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_scopeId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(placeItemsProvider(widget.name));
    final loading = ref.watch(placeAlbumListProvider).isLoading;
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    final selection = ref.read(_selectionProvider.notifier);

    final Widget header = selecting
        ? Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(
                _selectionProvider.select((s) => s.count),
              );
              return AlbumSelectionHeader(
                selectedCount: count,
                itemCount: items.length,
                onSelectAllToggle: () => count == items.length
                    ? selection.clearSelection()
                    : selection.selectAll([for (final i in items) i.id]),
                onClose: selection.exit,
              );
            },
          )
        : CollapsingSliverAppBar(
            title: widget.name,
            leading: const AppBackButton(),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: selection.start,
                ),
            ],
          );

    return MediaScope(
      id: _scopeId,
      mediaContext: MediaContext.album,
      items: placeItemsProvider(widget.name),
      albumId: _scopeId,
      child: PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) selection.exit();
        },
        child: Scaffold(
          bottomNavigationBar: selecting ? const SelectionActionBar() : null,
          body: items.isEmpty
              ? CustomScrollView(
                  slivers: [
                    header,
                    if (loading)
                      const SliverGalleryGridSkeleton(columns: placeGridColumns)
                    else
                      const SliverFillRemaining(hasScrollBody: false),
                  ],
                )
              : GalleryGrid(
                  controller: _scroll,
                  rows: ref.watch(placeRowsProvider(widget.name)),
                  items: items,
                  columns: placeGridColumns,
                  reversed: false,
                  viewerItems: placeItemsProvider(widget.name),
                  thumbTopInset:
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  leadingSlivers: [header],
                  // Fixed 4 columns (like the system gallery).
                  onZoomIn: () {},
                  onZoomOut: () {},
                ),
        ),
      ),
    );
  }
}
