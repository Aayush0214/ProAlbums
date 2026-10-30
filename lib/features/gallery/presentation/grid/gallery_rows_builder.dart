import 'dart:math' as math;

import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

/// Turns items into the flat row list for a given column count.
abstract final class GalleryRowsBuilder {
  /// Normal view: toolbar, then for every group a header and its rows.
  static List<GalleryRow> build({
    required List<MediaGroup> groups,
    required int columns,
  }) {
    final rows = <GalleryRow>[const ToolbarRow()];
    var firstIndexOfGroup = 0;

    for (final group in groups) {
      final items = group.items;
      rows.add(
        DateHeaderRow(
          day: group.day,
          count: items.length,
          itemIds: [for (final item in items) item.id],
          granularity: group.granularity,
        ),
      );

      for (var start = 0; start < items.length; start += columns) {
        final end = math.min(start + columns, items.length);
        rows.add(
          ItemsRow(
            items: items.sublist(start, end),
            firstIndex: firstIndexOfGroup + start,
          ),
        );
      }
      firstIndexOfGroup += items.length;
    }
    return rows;
  }

  /// Immersive view: ONE continuous grid, no toolbar, no headers.
  ///
  /// [alignToEnd] is for "newest at the bottom": the list then grows at its TOP
  /// while older pages load. Rows are cut from the END, so the rows at the
  /// bottom never change while that happens (only the top row may be short).
  static List<GalleryRow> buildFlat({
    required List<MediaItem> items,
    required int columns,
    required bool alignToEnd,
  }) {
    if (!alignToEnd) {
      return <GalleryRow>[
        for (var start = 0; start < items.length; start += columns)
          ItemsRow(
            items: items.sublist(start, math.min(start + columns, items.length)),
            firstIndex: start,
          ),
      ];
    }

    final rows = <GalleryRow>[];
    var end = items.length;
    while (end > 0) {
      final start = math.max(0, end - columns);
      rows.add(ItemsRow(items: items.sublist(start, end), firstIndex: start));
      end = start;
    }
    return rows.reversed.toList(growable: false);
  }
}
