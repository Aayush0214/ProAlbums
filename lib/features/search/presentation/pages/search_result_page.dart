import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';
import 'package:proalbums/features/search/presentation/search_providers.dart';
import 'package:proalbums/features/search/presentation/widgets/search_chips.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// A Search result (an answer, "View all", or a person / place / type from
/// the Search tab): the SHARED grid with fixed 4 columns and no date
/// headers, chips (years, then labels) that filter it, and the date range.
/// A person here is a plain grid (no slideshow page).
class SearchResultPage extends ConsumerStatefulWidget {
  const SearchResultPage({required this.target, super.key});

  final SearchTarget target;

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  final ScrollController _scroll = ScrollController();
  final Set<SearchChip> _chosen = {};

  SearchTarget get _target => widget.target;

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_target.scopeId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// What the selection bar / viewer offer, and the album they act on.
  (MediaContext, String?) get _context => switch (_target.kind) {
    SearchTargetKind.person => switch (int.tryParse(_target.key)) {
      final id? => (MediaContext.searchPerson, personAlbumId(id)),
      null => (MediaContext.search, null),
    },
    SearchTargetKind.place => (MediaContext.album, placeAlbumId(_target.key)),
    SearchTargetKind.thing => (
      MediaContext.thing,
      thingAlbumId(
        ThingKind.values.firstWhere(
          (k) => k.name == _target.key,
          orElse: () => ThingKind.documents,
        ),
      ),
    ),
    SearchTargetKind.answer ||
    SearchTargetKind.all => (MediaContext.search, null),
  };

  void _toggle(SearchChip chip) => setState(() {
    if (!_chosen.remove(chip)) _chosen.add(chip);
  });

  @override
  Widget build(BuildContext context) {
    final allChips = ref.watch(searchTargetChipsProvider(_target));
    // A chip that is gone (its last picture deleted) is no longer chosen.
    if (allChips.isNotEmpty) _chosen.retainAll(allChips);
    final chips = searchChipsKey(_chosen);
    final itemsProvider = searchTargetItemsProvider(_target, chips: chips);
    final items = ref.watch(itemsProvider);
    final loading =
        ref.watch(searchTargetIdsProvider(_target)).isLoading && items.isEmpty;
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    final selection = ref.read(_selectionProvider.notifier);
    final (mediaContext, albumId) = _context;

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
            title: _target.title,
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
      if (allChips.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: SearchChipsRow(
              chips: allChips,
              chosen: _chosen,
              onToggle: _toggle,
            ),
          ),
        ),
      if (items.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              dateRangeText(items),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
    ];

    return MediaScope(
      id: _target.scopeId,
      mediaContext: mediaContext,
      items: itemsProvider,
      albumId: albumId,
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
                      const SliverGalleryGridSkeleton(
                        columns: searchGridColumns,
                      )
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No images',
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : GalleryGrid(
                  controller: _scroll,
                  rows: ref.watch(
                    searchTargetRowsProvider(_target, chips: chips),
                  ),
                  items: items,
                  columns: searchGridColumns,
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

/// "June 24, 2021 to May 4, 2025" ([items] newest first); one day = that day.
String dateRangeText(List<MediaItem> items) {
  final format = DateFormat.yMMMMd();
  final first = format.format(items.last.createdAt);
  final last = format.format(items.first.createdAt);
  return first == last ? first : '$first to $last';
}
