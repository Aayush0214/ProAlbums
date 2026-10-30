import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/utils/date_label.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/thumbnail_size.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_query_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_view_settings_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/date_header.dart';
import 'package:proalbums/features/gallery/presentation/widgets/drag_select_gestures.dart';
import 'package:proalbums/features/gallery/presentation/widgets/fast_scroll_thumb.dart';
import 'package:proalbums/features/gallery/presentation/widgets/gallery_items_row.dart';
import 'package:proalbums/features/gallery/presentation/widgets/gallery_toolbar.dart';
import 'package:proalbums/features/gallery/presentation/widgets/immersive_date_label.dart';
import 'package:proalbums/features/gallery/presentation/widgets/pinch_zoom_detector.dart';
import 'package:proalbums/features/gallery/presentation/widgets/sticky_date_header.dart';

/// The scrolling part of the Photos tab.
class PhotosBody extends ConsumerStatefulWidget {
  const PhotosBody({required this.appBarExtent, super.key});

  /// Height of status bar + app bar (where the immersive date label goes under).
  final double appBarExtent;

  @override
  ConsumerState<PhotosBody> createState() => _PhotosBodyState();
}

class _PhotosBodyState extends ConsumerState<PhotosBody> {
  // Below this tile size a video badge shows only a camera icon.
  static const double _compactBadgeCellSize = 72;

  final ScrollController _scrollController = ScrollController();

  // Geometry is O(rows) to build, so keep it until something changes.
  GalleryGeometry? _geometry;
  double _viewportHeight = 0;

  bool _pinching = false;

  // The photo that was at the top before a zoom / view change. After the new
  // layout is ready we scroll back to it, so the screen does not "jump".
  int? _pendingAnchorItem;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GalleryGeometry _geometryFor(
    List<GalleryRow> rows,
    double width,
    int columns, {
    required bool reversed,
  }) {
    final cached = _geometry;
    if (cached != null &&
        identical(cached.rows, rows) &&
        cached.width == width &&
        cached.columns == columns &&
        cached.reversed == reversed) {
      return cached;
    }
    return _geometry = GalleryGeometry(
      rows: rows,
      width: width,
      columns: columns,
      reversed: reversed,
    );
  }

  /// Offset 0 is the start of the list: the TOP for "newest at the top", the
  /// BOTTOM (newest photos) for "newest at the bottom" (reversed list).
  void _jumpToStart() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  int? _currentAnchorItem() {
    final geometry = _geometry;
    if (geometry == null || !_scrollController.hasClients) return null;
    // At the very start: just stay at the start.
    if (_scrollController.offset <= 1) return null;

    final display = geometry.displayOffsetFor(
      _scrollController.offset,
      _viewportHeight,
    );
    return geometry.firstItemIndexAt(display);
  }

  void _restoreAnchor(int itemIndex) {
    final geometry = _geometry;
    if (geometry == null || !_scrollController.hasClients) return;

    final display = geometry.offsetOfItem(itemIndex);
    if (display == null) return;

    final target = geometry.controllerOffsetFor(display, _viewportHeight);
    final position = _scrollController.position;
    _scrollController.jumpTo(
      math.min(position.maxScrollExtent, math.max(position.minScrollExtent, target)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A different filter shows different photos: start from the beginning.
    ref.listen(photosQueryControllerProvider, (previous, next) {
      if (previous != next) _jumpToStart();
    });

    // These listeners run BEFORE the rebuild, so the old layout (and the photo
    // at the top of the screen) is still known.
    ref.listen(photosViewSettingsControllerProvider, (previous, next) {
      if (previous == null) return;
      if (previous.order != next.order) {
        _pendingAnchorItem = null;
        _jumpToStart();
      } else if (previous.columns != next.columns ||
          previous.showsImmersive != next.showsImmersive) {
        _pendingAnchorItem = _currentAnchorItem();
      }
    });

    final photos = ref.watch(photosControllerProvider);

    return photos.when(
      skipLoadingOnReload: true, // keep old photos while a new filter loads
      skipLoadingOnRefresh: false, // but show a spinner on "Try again"
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorView(
        message: error is Failure ? error.message : 'Something went wrong.',
        onRetry: () => ref.invalidate(photosControllerProvider),
      ),
      data: (_) => _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final rows = ref.watch(galleryRowsProvider);
    final settings = ref.watch(photosViewSettingsControllerProvider);
    final hasItems = ref.watch(
      photosDisplayItemsProvider.select((items) => items.isNotEmpty),
    );
    final immersive = ref.watch(photosImmersiveActiveProvider);
    final settingsController =
        ref.read(photosViewSettingsControllerProvider.notifier);
    final reversed = settings.order == MediaSortOrder.oldestFirst;

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    // Includes the height of the glass bottom bar (shell uses extendBody).
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;

        if (!hasItems) {
          return const Column(
            children: [
              SizedBox(height: GalleryGeometry.toolbarHeight, child: GalleryToolbar()),
              Expanded(child: _EmptyView()),
            ],
          );
        }

        final geometry = _geometryFor(
          rows,
          constraints.maxWidth,
          settings.columns,
          reversed: reversed,
        );
        final thumbnailSize = thumbnailSizeFor(
          cellSize: geometry.cellSize,
          devicePixelRatio: devicePixelRatio,
        );

        // The layout is ready: scroll back to the photo we remembered.
        final anchor = _pendingAnchorItem;
        if (anchor != null) {
          _pendingAnchorItem = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAnchor(anchor));
        }

        // In a reversed list index 0 is at the BOTTOM, so the list index and
        // the display row index run in opposite directions.
        int rowFor(int listIndex) =>
            reversed ? rows.length - 1 - listIndex : listIndex;

        return PinchZoomDetector(
          onZoomIn: settingsController.zoomIn,
          onZoomOut: settingsController.zoomOut,
          onPinchActiveChanged: (active) {
            if (_pinching != active) setState(() => _pinching = active);
          },
          child: Stack(
            children: [
              DragSelectGestures(
                controller: _scrollController,
                geometry: geometry,
                viewportHeight: constraints.maxHeight,
                enabled: !_pinching,
                child: ListView.builder(
                controller: _scrollController,
                reverse: reversed,
                // Two fingers = zoom, not scroll.
                physics: _pinching ? const NeverScrollableScrollPhysics() : null,
                padding: EdgeInsets.only(bottom: bottomPadding),
                // Build a bit beyond the screen, so thumbnails start loading
                // BEFORE they scroll into view. Tuned in the optimization pass.
                scrollCacheExtent: const ScrollCacheExtent.pixels(300),
                addAutomaticKeepAlives: false, // rows never need to stay alive
                itemCount: rows.length,
                // Fixed heights: Flutter does not have to measure each row.
                itemExtentBuilder: (index, dimensions) =>
                    geometry.extentOf(rowFor(index)),
                itemBuilder: (context, index) => _buildRow(
                  geometry,
                  rowFor(index),
                  thumbnailSize,
                ),
              ),
              ),
              Positioned.fill(
                child: FastScrollThumb(
                  controller: _scrollController,
                  geometry: geometry,
                  viewportHeight: constraints.maxHeight,
                  reversed: reversed,
                  topInset: immersive ? widget.appBarExtent + 8 : 8,
                  bottomInset: bottomPadding + 8,
                  labelAt: (displayOffset) {
                    final date = geometry.dateAt(displayOffset);
                    return date == null ? null : formatMonthLabel(date);
                  },
                ),
              ),
              if (immersive)
                Positioned(
                  top: widget.appBarExtent + 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: ImmersiveDateLabel(
                      controller: _scrollController,
                      geometry: geometry,
                      viewportHeight: constraints.maxHeight,
                    ),
                  ),
                )
              else
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  // IgnorePointer: touches pass through to the list underneath.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: StickyDateHeader(
                        controller: _scrollController,
                        geometry: geometry,
                        viewportHeight: constraints.maxHeight,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(GalleryGeometry geometry, int index, int thumbnailSize) {
    return switch (geometry.rows[index]) {
      ToolbarRow() => const GalleryToolbar(),
      DateHeaderRow(:final day, :final granularity, :final itemIds) =>
        DateHeader(day: day, itemIds: itemIds, granularity: granularity),
      ItemsRow(:final items) => GalleryItemsRow(
          items: items,
          cellSize: geometry.cellSize,
          thumbnailSize: thumbnailSize,
          compactBadge: geometry.cellSize < _compactBadgeCellSize,
        ),
    };
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(photosQueryControllerProvider.select((q) => q.kind));
    final message = switch (kind) {
      MediaKind.all => 'No photos or videos yet',
      MediaKind.images => 'No photos found',
      MediaKind.videos => 'No videos found',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(message, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
