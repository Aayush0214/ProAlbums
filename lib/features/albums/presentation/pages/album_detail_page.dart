import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/providers/album_prefs_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/album_rows_provider.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/browsing_order_sheet.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

enum _DetailMenu { zoomIn, zoomOut, browsingOrder, changeCover }

/// What is inside one album: tap opens the viewer (swipe through THIS album).
/// The grid is the SAME [GalleryGrid] as the Photos tab, so it has the same
/// features: pinch zoom, drag select, the fast scroll handle, the same
/// thumbnails. Only the app bar and the data are the album's own.
class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({
    required this.albumId,
    required this.title,
    super.key,
  });

  final String albumId;
  final String title;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  final ScrollController _scroll = ScrollController();
  bool _hadItems = false;
  bool _closing = false;

  // This album's OWN selection (same bar and tiles as the Photos tab, but
  // the Photos tab keeps its selection). Dropped by itself when the page
  // closes.
  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(MediaScope.album(widget.albumId));

  MediaSelectionController get _selection =>
      ref.read(_selectionProvider.notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final albumId = widget.albumId;
    final loaded = ref.watch(albumItemsProvider(albumId));
    final items = ref.watch(albumDisplayItemsProvider(albumId));
    final settings = ref.watch(albumViewSettingsProvider);
    final controller = ref.read(albumViewSettingsProvider.notifier);
    final loading = loaded.isLoading && items.isEmpty;
    // Only "is selecting?" here. The count is watched inside the header, so
    // selecting one more picture does not rebuild the whole page.
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));

    if (items.isNotEmpty) {
      _hadItems = true;
    } else if (_hadItems && !loading && !_closing) {
      // The last picture was deleted or moved away: the album is gone, so
      // leave it too (back to the albums list), like the system gallery.
      _closing = true;
      _closeWhenOnTop();
    }

    final header = selecting
        ? _selectionHeader(items)
        : _appBar(settings.canZoomIn, settings.canZoomOut);

    return MediaScope(
      id: MediaScope.album(albumId),
      mediaContext: MediaContext.album,
      items: albumDisplayItemsProvider(albumId),
      albumId: albumId,
      child: PopScope(
        // Back while selecting = leave select mode, not the album.
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _selection.exit();
        },
        child: Scaffold(
          bottomNavigationBar: selecting
              ? const SelectionActionBar()
              : null,
          body: items.isEmpty
              ? CustomScrollView(
                  slivers: [
                    header,
                    if (loading)
                      // Not blank while the album loads.
                      SliverGalleryGridSkeleton(columns: settings.columns)
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            loaded.hasError
                                ? 'Could not load this album.'
                                : 'No photos or videos',
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
                  rows: ref.watch(albumGalleryRowsProvider(albumId)),
                  items: items,
                  columns: settings.columns,
                  reversed: false,
                  // "Newest at the bottom": start scrolled to the end, so the
                  // newest pictures are what you see first (like Photos).
                  startAtEnd: settings.order == MediaSortOrder.oldestFirst,
                  viewerItems: albumDisplayItemsProvider(albumId),
                  // The handle's track starts under the pinned app bar.
                  thumbTopInset:
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  leadingSlivers: [header],
                  onZoomIn: controller.zoomIn,
                  onZoomOut: controller.zoomOut,
                ),
        ),
      ),
    );
  }

  Widget _selectionHeader(List<MediaItem> items) {
    return Consumer(
      builder: (context, ref, _) {
        final count = ref.watch(_selectionProvider.select((s) => s.count));
        return AlbumSelectionHeader(
          selectedCount: count,
          itemCount: items.length,
          onSelectAllToggle: () => count == items.length
              ? _selection.clearSelection()
              : _selection.selectAll([for (final i in items) i.id]),
          onClose: _selection.exit,
        );
      },
    );
  }

  Widget _appBar(bool canZoomIn, bool canZoomOut) {
    return CollapsingSliverAppBar(
      title: widget.title,
      leading: const AppBackButton(),
      actions: [
        IconButton(
          tooltip: 'Select',
          icon: const Icon(LucideIcons.squareCheck),
          onPressed: _selection.start,
        ),
        PopupMenuButton<_DetailMenu>(
          icon: const Icon(LucideIcons.ellipsisVertical),
          tooltip: 'More',
          onSelected: _onMenu,
          itemBuilder: (context) => [
            // Same rule as the Photos tab: no "Zoom in" at the biggest
            // photos, no "Zoom out" at the smallest.
            if (canZoomIn)
              const PopupMenuItem(
                value: _DetailMenu.zoomIn,
                child: Text('Zoom in'),
              ),
            if (canZoomOut)
              const PopupMenuItem(
                value: _DetailMenu.zoomOut,
                child: Text('Zoom out'),
              ),
            const PopupMenuItem(
              value: _DetailMenu.browsingOrder,
              child: Text('Browsing order'),
            ),
            const PopupMenuItem(
              value: _DetailMenu.changeCover,
              child: Text('Change cover'),
            ),
          ],
        ),
      ],
    );
  }

  /// If the viewer is still open on top of this page it closes first; wait
  /// until this page is the visible one, then close it.
  Future<void> _closeWhenOnTop() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        if (context.canPop()) context.pop();
        return;
      }
    }
  }

  Future<void> _changeCover() async {
    final mediaId = await context.push<String>(
      AppRoutes.changeCover(widget.albumId),
    );
    if (mediaId == null) return;
    ref
        .read(albumPrefsControllerProvider.notifier)
        .setCover(widget.title, mediaId);
    if (mounted) showAppSnackBar(context, 'Cover changed.');
  }

  void _onMenu(_DetailMenu item) {
    final controller = ref.read(albumViewSettingsProvider.notifier);
    switch (item) {
      case _DetailMenu.zoomIn:
        controller.zoomIn();
      case _DetailMenu.zoomOut:
        controller.zoomOut();
      case _DetailMenu.browsingOrder:
        // The SAME floating card as the Photos tab.
        showBrowsingOrderSheet(
          context,
          current: ref.read(albumViewSettingsProvider).order,
          onSelected: controller.setOrder,
        );
      case _DetailMenu.changeCover:
        _changeCover();
    }
  }
}
