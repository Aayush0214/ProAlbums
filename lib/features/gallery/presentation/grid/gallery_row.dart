import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// The Photos screen is ONE flat list of rows. Three kinds of rows exist.
///
/// WHY flat rows and not "one SliverGrid per day"? Every row has a height we
/// can compute without building it (see GalleryGeometry). That gives us exact
/// scroll offsets for the sticky date header, the date label, zoom anchoring
/// and (later) fast scroll, and the list can skip measuring children.
///
/// Rows are always stored in DISPLAY order, top to bottom.
sealed class GalleryRow {
  const GalleryRow();
}

/// "Library 2,660 items" + filter chips. First row of the grouped view only.
final class ToolbarRow extends GalleryRow {
  const ToolbarRow();
}

final class DateHeaderRow extends GalleryRow {
  const DateHeaderRow({
    required this.day,
    required this.count,
    this.itemIds = const <String>[],
    this.granularity = GroupGranularity.day,
  });

  final DateTime day;

  /// Number of items of this day.
  final int count;

  /// Ids of this day's items: the date checkbox selects them all at once.
  final List<String> itemIds;
  final GroupGranularity granularity;
}

/// One line of thumbnails (at most `columns` items).
final class ItemsRow extends GalleryRow {
  const ItemsRow({required this.items, required this.firstIndex});

  final List<MediaItem> items;

  /// Position of `items.first` in the DISPLAYED, ungrouped item list.
  /// The viewer (Phase 3) and multi-select (Phase 2.3) need it.
  final int firstIndex;
}
