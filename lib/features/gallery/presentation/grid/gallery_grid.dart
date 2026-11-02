import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/core/utils/date_label.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/thumbnail_size.dart';
import 'package:proalbums/features/gallery/presentation/widgets/date_header.dart';
import 'package:proalbums/features/gallery/presentation/widgets/drag_select_gestures.dart';
import 'package:proalbums/features/gallery/presentation/widgets/fast_scroll_thumb.dart';
import 'package:proalbums/features/gallery/presentation/widgets/gallery_items_row.dart';
import 'package:proalbums/features/gallery/presentation/widgets/immersive_date_label.dart';
import 'package:proalbums/features/gallery/presentation/widgets/pinch_zoom_detector.dart';
import 'package:proalbums/features/gallery/presentation/widgets/sticky_date_header.dart';

/// THE photo grid of the app. Photos, every album (and later Search and For
/// You) show their pictures with THIS widget, so they all have the same
/// features and the same speed:
///
/// - pinch to zoom, and the photo at the top stays in place while zooming
/// - long press + slide = drag select (auto scroll near the edges)
/// - the draggable scroll handle with the month bubble on the right edge
/// - sticky date headers (when the rows have them)
/// - ONE thumbnail size rule, so every grid fills the SAME image cache
///
/// The owner supplies the data: [rows] (see GalleryRowsBuilder), the [items]
/// they were cut from, and the zoom callbacks. Anything above the first row
/// (an album's app bar) goes in [leadingSlivers].
class GalleryGrid extends StatefulWidget {
  const GalleryGrid({
    required this.controller,
    required this.rows,
    required this.items,
    required this.columns,
    required this.reversed,
    required this.onZoomIn,
    required this.onZoomOut,
    this.viewerItems,
    this.immersive = false,
    this.immersiveLabelTop = 0,
    this.thumbTopInset = 8,
    this.toolbar,
    this.leadingSlivers = const <Widget>[],
    this.startAtEnd = false,
    super.key,
  }) : assert(
          !(reversed && startAtEnd),
          'reversed already starts at the newest end',
        );

  /// Owned by the caller (it may need to jump or read the offset). The grid
  /// never disposes it.
  final ScrollController controller;

  /// Rows in DISPLAY order, top to bottom.
  final List<GalleryRow> rows;

  /// The items in DISPLAY order (what drag select numbers).
  final List<MediaItem> items;
  final int columns;

  /// "Newest at the bottom" done with a reversed list (the Photos tab).
  final bool reversed;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// What the viewer swipes through. null = the Photos tab list.
  final ProviderListenable<List<MediaItem>>? viewerItems;

  /// The "August 28 - today" label instead of date headers.
  final bool immersive;

  /// Distance of that label from the top (under the app bar).
  final double immersiveLabelTop;

  /// Free space above the scroll handle's track (app bar, status bar).
  final double thumbTopInset;

  /// Shown for a [ToolbarRow] (Photos tab only).
  final Widget? toolbar;

  /// Slivers ABOVE the first row, in the same scroll view (an album's
  /// collapsing app bar). Not for a reversed grid.
  final List<Widget> leadingSlivers;

  /// Start scrolled to the end (an album with "newest at the bottom" that is
  /// not a reversed list).
  final bool startAtEnd;

  @override
  State<GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends State<GalleryGrid> {
  // Below this tile size a video badge shows only a camera icon.
  static const double _compactBadgeCellSize = 72;

  final GridOrigin _origin = GridOrigin();

  // Geometry is O(rows) to build, so keep it until something changes.
  GalleryGeometry? _geometry;
  double _viewportHeight = 0;
  bool _pinching = false;

  // The photo that was at the top before a zoom / view change. After the new
  // layout is ready we scroll back to it, so the screen does not "jump".
  int? _pendingAnchorItem;

  ScrollController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.startAtEnd) _afterFrame(_jumpToEnd);
  }

  @override
  void didUpdateWidget(GalleryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Runs BEFORE the new layout, so the old layout (and the photo at the top
    // of the screen) is still known.
    final orderChanged = oldWidget.reversed != widget.reversed ||
        oldWidget.startAtEnd != widget.startAtEnd;
    if (orderChanged) {
      _pendingAnchorItem = null;
      _afterFrame(widget.startAtEnd ? _jumpToEnd : _jumpToStart);
    } else if (oldWidget.columns != widget.columns ||
        oldWidget.immersive != widget.immersive) {
      _pendingAnchorItem = _currentAnchorItem();
    }
  }

  /// Scroll changes are not allowed while building, so they wait for the end
  /// of the frame.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) action();
    });
  }

  /// Offset 0 is the start of the list: the TOP for "newest at the top", the
  /// BOTTOM (newest photos) for a reversed list.
  void _jumpToStart() => _controller.jumpTo(0);

  void _jumpToEnd() =>
      _controller.jumpTo(_controller.position.maxScrollExtent);

  GalleryGeometry _geometryFor(double width) {
    final cached = _geometry;
    if (cached != null &&
        identical(cached.rows, widget.rows) &&
        cached.width == width &&
        cached.columns == widget.columns &&
        cached.reversed == widget.reversed) {
      return cached;
    }
    return _geometry = GalleryGeometry(
      rows: widget.rows,
      width: width,
      columns: widget.columns,
      reversed: widget.reversed,
      origin: _origin,
    );
  }

  int? _currentAnchorItem() {
    final geometry = _geometry;
    if (geometry == null || !_controller.hasClients) return null;
    final offset = _controller.offset;
    // At the very start: just stay at the start.
    if (offset <= 1) return null;
    final display = geometry.displayOffsetFor(offset, _viewportHeight);
    return geometry.firstItemIndexAt(display);
  }

  void _restoreAnchor(int itemIndex) {
    final geometry = _geometry;
    if (geometry == null || !_controller.hasClients) return;

    final display = geometry.offsetOfItem(itemIndex);
    if (display == null) return;

    final target = geometry.controllerOffsetFor(display, _viewportHeight);
    final position = _controller.position;
    _controller.jumpTo(
      math.min(
        position.maxScrollExtent,
        math.max(position.minScrollExtent, target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    // Includes the height of the glass bottom bar (the shell extends the body
    // under it).
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final reversed = widget.reversed;
    final rows = widget.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;

        final geometry = _geometryFor(constraints.maxWidth);
        final thumbnailSize = thumbnailSizeFor(
          cellSize: geometry.cellSize,
          devicePixelRatio: devicePixelRatio,
        );

        // The layout is ready: scroll back to the photo we remembered.
        final anchor = _pendingAnchorItem;
        if (anchor != null) {
          _pendingAnchorItem = null;
          _afterFrame(() => _restoreAnchor(anchor));
        }

        // In a reversed list index 0 is at the BOTTOM, so the list index and
        // the display row index run in opposite directions.
        int rowFor(int listIndex) =>
            reversed ? rows.length - 1 - listIndex : listIndex;

        return PinchZoomDetector(
          onZoomIn: widget.onZoomIn,
          onZoomOut: widget.onZoomOut,
          onPinchActiveChanged: (active) {
            if (_pinching != active) setState(() => _pinching = active);
          },
          child: Stack(
            children: [
              DragSelectGestures(
                controller: _controller,
                geometry: geometry,
                viewportHeight: constraints.maxHeight,
                items: widget.items,
                enabled: !_pinching,
                child: CustomScrollView(
                  controller: _controller,
                  reverse: reversed,
                  // Two fingers = zoom, not scroll.
                  physics:
                      _pinching ? const NeverScrollableScrollPhysics() : null,
                  // Build a bit beyond the screen, so thumbnails start loading
                  // BEFORE they scroll into view.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(300),
                  slivers: [
                    ...widget.leadingSlivers,
                    // Tells the geometry how much sits above the first row.
                    // (NOT a SliverLayoutBuilder: that rebuilds its whole
                    // subtree on every scroll frame. This only reads a number
                    // while laying out.)
                    _SliverOriginReporter(
                      origin: _origin,
                      child: SliverPadding(
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        sliver: SliverVariedExtentList(
                          // Fixed heights: Flutter does not have to measure
                          // each row.
                          itemExtentBuilder: (index, dimensions) =>
                              geometry.extentOf(rowFor(index)),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRow(
                              geometry,
                              rowFor(index),
                              thumbnailSize,
                            ),
                            childCount: rows.length,
                            // Rows never need to stay alive.
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.immersive)
                Positioned(
                  top: widget.immersiveLabelTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: ImmersiveDateLabel(
                      controller: _controller,
                      geometry: geometry,
                      viewportHeight: constraints.maxHeight,
                    ),
                  ),
                )
              else if (geometry.hasHeaders)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  // IgnorePointer: touches pass through to the list underneath.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: StickyDateHeader(
                        controller: _controller,
                        geometry: geometry,
                        viewportHeight: constraints.maxHeight,
                      ),
                    ),
                  ),
                ),
              // LAST = on top of the date header, so the handle is never half
              // hidden when the header is pushed by the next one.
              Positioned.fill(
                child: FastScrollThumb(
                  controller: _controller,
                  geometry: geometry,
                  viewportHeight: constraints.maxHeight,
                  reversed: reversed,
                  topInset: widget.thumbTopInset,
                  bottomInset: bottomPadding + 8,
                  labelAt: (displayOffset) {
                    final date = geometry.dateAt(displayOffset);
                    return date == null ? null : formatMonthLabel(date);
                  },
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
      ToolbarRow() => widget.toolbar ?? const SizedBox.shrink(),
      DateHeaderRow(:final day, :final granularity, :final itemIds) =>
        DateHeader(day: day, itemIds: itemIds, granularity: granularity),
      ItemsRow(:final items) => GalleryItemsRow(
          items: items,
          cellSize: geometry.cellSize,
          thumbnailSize: thumbnailSize,
          compactBadge: geometry.cellSize < _compactBadgeCellSize,
          viewerItems: widget.viewerItems,
        ),
    };
  }
}

/// Writes "how much scroll extent sits before this sliver" into [origin] while
/// the sliver is laid out. It adds no widgets and rebuilds nothing.
class _SliverOriginReporter extends SingleChildRenderObjectWidget {
  const _SliverOriginReporter({required this.origin, super.child});

  final GridOrigin origin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverOriginReporter(origin);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverOriginReporter renderObject,
  ) {
    renderObject.origin = origin;
  }
}

class _RenderSliverOriginReporter extends RenderProxySliver {
  _RenderSliverOriginReporter(this.origin);

  GridOrigin origin;

  @override
  void performLayout() {
    origin.extent = constraints.precedingScrollExtent;
    super.performLayout();
  }
}
