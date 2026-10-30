import 'dart:math' as math;

import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

/// Sizes and scroll offsets of every row, for one (rows, width, columns).
///
/// All heights are plain numbers, so nothing has to be laid out to know where
/// a row starts. Everything here works in DISPLAY coordinates: 0 = the top of
/// the content, growing downwards. A reversed ListView ("newest at the bottom")
/// counts its scroll offset from the BOTTOM, so [displayOffsetFor] and
/// [controllerOffsetFor] convert between the two.
final class GalleryGeometry {
  GalleryGeometry({
    required this.rows,
    required this.width,
    required this.columns,
    this.reversed = false,
  });

  static const double gap = 2;
  static const double toolbarHeight = 104;
  static const double headerHeight = 52;

  final List<GalleryRow> rows;
  final double width;
  final int columns;

  /// true when the ListView is reversed (newest at the bottom).
  final bool reversed;

  /// Square thumbnail side.
  late final double cellSize = (width - gap * (columns - 1)) / columns;

  /// A row of thumbnails + the gap below it.
  late final double itemsRowExtent = cellSize + gap;

  /// _starts[i] = display offset where row i begins; last entry = total height.
  late final List<double> _starts = _computeStarts();

  /// Row indexes of all date headers, in order.
  late final List<int> _headerRows = <int>[
    for (var i = 0; i < rows.length; i++)
      if (rows[i] is DateHeaderRow) i,
  ];

  /// Row indexes of all thumbnail rows, in order (firstIndex ascending).
  late final List<int> _itemRows = <int>[
    for (var i = 0; i < rows.length; i++)
      if (rows[i] is ItemsRow) i,
  ];

  double extentOf(int rowIndex) => switch (rows[rowIndex]) {
        ToolbarRow() => toolbarHeight,
        DateHeaderRow() => headerHeight,
        ItemsRow() => itemsRowExtent,
      };

  double startOf(int rowIndex) => _starts[rowIndex];

  double get totalExtent => _starts.last;

  /// ScrollController offset -> top-down offset.
  double displayOffsetFor(double controllerOffset, double viewportHeight) =>
      reversed
          ? math.max(0, totalExtent - controllerOffset - viewportHeight)
          : controllerOffset;

  /// top-down offset -> ScrollController offset (inverse of the above).
  double controllerOffsetFor(double displayOffset, double viewportHeight) =>
      reversed ? totalExtent - displayOffset - viewportHeight : displayOffset;

  /// The row that covers [displayOffset] (clamped to the first/last row).
  int rowIndexAt(double displayOffset) {
    if (rows.isEmpty) return 0;
    var low = 0;
    var high = rows.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (startOf(mid) <= displayOffset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// First and last row that are (at least partly) on screen.
  ({int first, int last}) visibleRowRange(
    double displayOffset,
    double viewportHeight,
  ) =>
      (
        first: rowIndexAt(displayOffset),
        last: rowIndexAt(displayOffset + viewportHeight),
      );

  /// Index of the first PHOTO at or below [displayOffset] (skips headers).
  /// Used to keep the same photo in view when the zoom level changes.
  int? firstItemIndexAt(double displayOffset) {
    for (var i = rowIndexAt(displayOffset); i < rows.length; i++) {
      final row = rows[i];
      if (row is ItemsRow) return row.firstIndex;
    }
    return null;
  }

  /// The photo under a finger: [displayOffset] is the top-down position of the
  /// touch, [x] the horizontal position. null on headers / outside the list.
  int? itemIndexAt(double displayOffset, double x) {
    if (rows.isEmpty || displayOffset < 0 || displayOffset >= totalExtent) {
      return null;
    }
    final row = rows[rowIndexAt(displayOffset)];
    if (row is! ItemsRow) return null;
    final column = (x / (cellSize + gap)).floor().clamp(0, row.items.length - 1);
    return row.firstIndex + column;
  }

  /// The date of the content at [displayOffset] (the fast-scroll bubble).
  DateTime? dateAt(double displayOffset) {
    for (var i = rowIndexAt(displayOffset); i < rows.length; i++) {
      switch (rows[i]) {
        case DateHeaderRow(:final day):
          return day;
        case ItemsRow(:final items):
          return items.first.createdAt;
        case ToolbarRow():
          continue;
      }
    }
    return null;
  }

  /// Display offset of the row that contains the photo [itemIndex].
  double? offsetOfItem(int itemIndex) {
    var low = 0;
    var high = _itemRows.length - 1;
    int? found;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final row = rows[_itemRows[mid]] as ItemsRow;
      if (row.firstIndex <= itemIndex) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found == null ? null : startOf(_itemRows[found]);
  }

  /// Which date header is "stuck" at the top when the content is scrolled to
  /// [displayOffset]? null while the toolbar is still showing.
  ///
  /// [nextStart] is where the NEXT header begins (null for the last group),
  /// used to push the stuck header out of the way.
  ({int rowIndex, double? nextStart})? stickyHeaderAt(double displayOffset) {
    // Binary search: the last header that starts at or above [displayOffset].
    var low = 0;
    var high = _headerRows.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (startOf(_headerRows[mid]) <= displayOffset) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (found == -1) return null;

    final next = found + 1 < _headerRows.length
        ? startOf(_headerRows[found + 1])
        : null;
    return (rowIndex: _headerRows[found], nextStart: next);
  }

  List<double> _computeStarts() {
    final starts = List<double>.filled(rows.length + 1, 0);
    var offset = 0.0;
    for (var i = 0; i < rows.length; i++) {
      starts[i] = offset;
      offset += extentOf(i);
    }
    starts[rows.length] = offset;
    return starts;
  }
}
