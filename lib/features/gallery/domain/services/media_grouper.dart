import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Business rule: "photos are grouped by the day (or month) they were taken".
/// Pure Dart, no Flutter, trivially unit-testable.
abstract final class MediaGrouper {
  /// [items] must already be sorted by date (newest first OR oldest first).
  /// Neighbouring items of the same bucket end up in one group, so one pass
  /// (O(n)) is enough, no sorting or map needed.
  static List<MediaGroup> group(
    List<MediaItem> items,
    GroupGranularity granularity,
  ) {
    final groups = <MediaGroup>[];
    for (final item in items) {
      final created = item.createdAt;
      final key = switch (granularity) {
        GroupGranularity.day => DateTime(created.year, created.month, created.day),
        GroupGranularity.month => DateTime(created.year, created.month),
      };
      if (groups.isEmpty || groups.last.day != key) {
        groups.add(
          MediaGroup(day: key, items: <MediaItem>[], granularity: granularity),
        );
      }
      groups.last.items.add(item);
    }
    return groups;
  }

  static List<MediaGroup> groupByDay(List<MediaItem> items) =>
      group(items, GroupGranularity.day);
}
