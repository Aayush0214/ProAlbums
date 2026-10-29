enum MediaType { image, video }

/// One photo or video, as the app understands it.
///
/// Pure Dart on purpose: no plugin types here. The data layer converts the
/// plugin's AssetEntity into this class (see media_item_mapper.dart).
/// Equality is by value, so tests and providers can compare items safely.
final class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.width,
    required this.height,
    this.duration = Duration.zero,
    this.isFavorite = false,
  });

  final String id;
  final MediaType type;
  final DateTime createdAt;
  final int width;
  final int height;

  /// Only meaningful for videos.
  final Duration duration;
  final bool isFavorite;

  bool get isVideo => type == MediaType.video;

  @override
  bool operator ==(Object other) =>
      other is MediaItem &&
      other.id == id &&
      other.type == type &&
      other.createdAt == createdAt &&
      other.width == width &&
      other.height == height &&
      other.duration == duration &&
      other.isFavorite == isFavorite;

  @override
  int get hashCode =>
      Object.hash(id, type, createdAt, width, height, duration, isFavorite);

  @override
  String toString() => 'MediaItem($id, $type)';
}
