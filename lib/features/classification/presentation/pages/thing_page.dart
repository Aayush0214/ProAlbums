import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// One thing's pictures (Documents, Food…), like an album: the SHARED grid
/// (fixed 4 columns, no date headers), the shared viewer, the album's
/// select bar. Documents get the chips All / Blackboard writing (when there
/// is any).
class ThingPage extends ConsumerStatefulWidget {
  const ThingPage({required this.kind, super.key});

  final ThingKind kind;

  @override
  ConsumerState<ThingPage> createState() => _ThingPageState();
}

class _ThingPageState extends ConsumerState<ThingPage> {
  final ScrollController _scroll = ScrollController();
  bool _blackboardOnly = false;

  String get _scopeId => thingAlbumId(widget.kind);

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_scopeId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final itemsProvider = thingItemsProvider(
      kind,
      blackboardOnly: _blackboardOnly,
    );
    final items = ref.watch(itemsProvider);
    final hasBlackboard =
        kind == ThingKind.documents &&
        ref.watch(
          thingItemsProvider(
            kind,
            blackboardOnly: true,
          ).select((list) => list.isNotEmpty),
        );
    final loading = ref.watch(thingAlbumListProvider).isLoading;
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
            title: kind.title,
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

    final leading = <Widget>[
      header,
      if (hasBlackboard && !selecting)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: !_blackboardOnly,
                  onSelected: (_) => setState(() => _blackboardOnly = false),
                ),
                ChoiceChip(
                  label: const Text('Blackboard writing'),
                  selected: _blackboardOnly,
                  onSelected: (_) => setState(() => _blackboardOnly = true),
                ),
              ],
            ),
          ),
        ),
    ];

    return MediaScope(
      id: _scopeId,
      mediaContext: MediaContext.thing,
      items: itemsProvider,
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
                    ...leading,
                    if (loading)
                      const SliverGalleryGridSkeleton(columns: thingGridColumns)
                    else
                      const SliverFillRemaining(hasScrollBody: false),
                  ],
                )
              : GalleryGrid(
                  controller: _scroll,
                  rows: ref.watch(
                    thingRowsProvider(kind, blackboardOnly: _blackboardOnly),
                  ),
                  items: items,
                  columns: thingGridColumns,
                  reversed: false,
                  viewerItems: itemsProvider,
                  thumbTopInset:
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  leadingSlivers: leading,
                  // Fixed 4 columns (like the system gallery).
                  onZoomIn: () {},
                  onZoomOut: () {},
                ),
        ),
      ),
    );
  }
}
