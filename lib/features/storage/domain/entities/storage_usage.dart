/// How the phone's internal storage is used (all numbers in bytes).
final class StorageUsage {
  const StorageUsage({
    required this.total,
    required this.free,
    required this.photos,
    required this.videos,
    required this.screenshots,
    required this.trash,
  });

  final int total;
  final int free;
  final int photos;
  final int videos;
  final int screenshots;
  final int trash;

  int get used => (total - free).clamp(0, total);

  /// Everything that is not a picture or video of the gallery: apps, system,
  /// documents ... Never negative.
  int get other {
    final known = photos + videos + screenshots + trash;
    return (used - known).clamp(0, used);
  }

  /// The parts of the bar, in order. A part is a share of [total].
  List<({StorageKind kind, int bytes})> get segments => [
        (kind: StorageKind.photos, bytes: photos),
        (kind: StorageKind.videos, bytes: videos),
        (kind: StorageKind.screenshots, bytes: screenshots),
        (kind: StorageKind.trash, bytes: trash),
        (kind: StorageKind.other, bytes: other),
      ];
}

enum StorageKind { photos, videos, screenshots, trash, other, free }
