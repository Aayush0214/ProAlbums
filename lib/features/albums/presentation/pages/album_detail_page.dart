import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/providers/album_prefs_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/browsing_order_sheet.dart';
import 'package:proalbums/features/gallery/presentation/widgets/pinch_zoom_detector.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selectable_tile.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

enum _DetailMenu { zoomIn, zoomOut, browsingOrder, changeCover }

/// What is inside one album: a grid; tap opens the viewer (swipe through THIS
/// album). Zoom (pinch + menu) and "Browsing order" are the same components
/// and rules as the Photos tab. Select, Change cover and Move/Copy come next.
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
  static const double _gap = 1;

  final ScrollController _scroll = ScrollController();
  bool _pinching = false;
  bool _hadItems = false;
  bool _closing = false;
  MediaSortOrder? _positionedFor;

  // The Photos tab's selection state is reused here (same bottom bar, same
  // tile). It must be OFF again when this page closes.
  late final PhotosSelectionController _selection =
      ref.read(photosSelectionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future<void>(_selection.exit);
  }

  @override
  void dispose() {
    _scroll.dispose();
    Future<void>(_selection.exit);
    super.dispose();
  }

  /// "Newest at the bottom": the list starts scrolled to the end, so the
  /// newest pictures are what you see first (same as the Photos tab).
  void _positionIfNeeded(MediaSortOrder order) {
    if (_positionedFor == order) return;
    _positionedFor = order;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(
        order == MediaSortOrder.oldestFirst
            ? _scroll.position.maxScrollExtent
            : 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final albumId = widget.albumId;
    final loaded = ref.watch(albumItemsProvider(albumId));
    final items = ref.watch(albumDisplayItemsProvider(albumId));
    final settings = ref.watch(albumViewSettingsProvider);
    final controller = ref.read(albumViewSettingsProvider.notifier);
    final loading = loaded.isLoading && items.isEmpty;
    final selection = ref.watch(photosSelectionControllerProvider);
    final selecting = selection.active;

    if (items.isNotEmpty) {
      _hadItems = true;
      _positionIfNeeded(settings.order);
    } else if (_hadItems && !loading && !_closing) {
      // The last picture was deleted or moved away: the album is gone, so
      // leave it too (back to the albums list), like the system gallery.
      _closing = true;
      _closeWhenOnTop();
    }

    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final columns = settings.columns;
    final cell = (width - _gap * (columns - 1)) / columns;
    // Thumbnail size in pixels, in steps of 64 so the cache is reused.
    final thumb = math.max(128, (cell * dpr / 64).ceil() * 64);

    return PopScope(
      // Back while selecting = leave select mode, not the album.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selection.exit();
      },
      child: Scaffold(
      bottomNavigationBar: selecting
          ? SelectionActionBar(items: albumDisplayItemsProvider(albumId))
          : null,
      body: PinchZoomDetector(
        onZoomIn: controller.zoomIn,
        onZoomOut: controller.zoomOut,
        onPinchActiveChanged: (active) {
          if (_pinching != active) setState(() => _pinching = active);
        },
        child: CustomScrollView(
            controller: _scroll,
            // Two fingers = zoom, not scroll.
            physics: _pinching ? const NeverScrollableScrollPhysics() : null,
            slivers: [
              if (selecting)
                AlbumSelectionHeader(
                  selectedCount: selection.count,
                  itemCount: items.length,
                  onSelectAllToggle: () => selection.count == items.length
                      ? _selection.clearSelection()
                      : _selection.selectAll([for (final i in items) i.id]),
                  onClose: _selection.exit,
                )
              else
              CollapsingSliverAppBar(
                title: widget.title,
                leading: const BackButton(),
                actions: [
                  IconButton(
                    tooltip: 'Select',
                    icon: const Icon(Icons.check_box_outlined),
                    onPressed: _selection.start,
                  ),
                  PopupMenuButton<_DetailMenu>(
                    tooltip: 'More',
                    onSelected: (item) => _onMenu(item),
                    itemBuilder: (context) => [
                      // Same rule as the Photos tab: no "Zoom in" at the
                      // biggest photos, no "Zoom out" at the smallest.
                      if (settings.canZoomIn)
                        const PopupMenuItem(
                          value: _DetailMenu.zoomIn,
                          child: Text('Zoom in'),
                        ),
                      if (settings.canZoomOut)
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
              ),
              if (loading)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      loaded.hasError
                          ? 'Could not load this album.'
                          : 'No photos or videos',
                      style: context.textTheme.bodyLarge
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ),
                )
              else
                SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: _gap,
                    crossAxisSpacing: _gap,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SelectableTile(
                      key: ValueKey(item.id),
                      item: item,
                      thumbnailSize: thumb,
                      compact: columns >= 6,
                      items: albumDisplayItemsProvider(albumId),
                      // Long press = start selecting with this picture.
                      onLongPress: () => _selection.startWith(item.id),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
      ),
      ),
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
    final mediaId =
        await context.push<String>(AppRoutes.changeCover(widget.albumId));
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
