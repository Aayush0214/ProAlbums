import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// One chunk of the library. We never load thousands of items at once,
/// the grid asks for page 0, then page 1, ... while scrolling.
final class MediaPage {
  const MediaPage({required this.items, required this.hasMore});

  final List<MediaItem> items;

  /// false when this was the last page.
  final bool hasMore;
}
