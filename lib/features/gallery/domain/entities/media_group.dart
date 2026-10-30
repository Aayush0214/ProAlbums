import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// How photos are bucketed under a header.
enum GroupGranularity { day, month }

/// All media of one calendar day (or one month in the overview).
final class MediaGroup {
  const MediaGroup({
    required this.day,
    required this.items,
    this.granularity = GroupGranularity.day,
  });

  /// Local date at 00:00 (for a month group: the 1st of the month).
  final DateTime day;
  final List<MediaItem> items;
  final GroupGranularity granularity;
}
