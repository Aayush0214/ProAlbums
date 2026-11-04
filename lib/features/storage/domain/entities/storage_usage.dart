/// How the phone's internal storage is used (all numbers in bytes).
final class StorageUsage {
  const StorageUsage({
    required this.total,
    required this.free,
    required this.photos,
    required this.videos,
    required this.screenshots,
    required this.trash,
    this.hidden = 0,
    this.camera = 0,
    this.whatsapp = 0,
    this.downloads = 0,
  });

  final int total;
  final int free;
  final int photos;
  final int videos;
  final int screenshots;
  final int trash;

  /// The private vault's encrypted files (Hidden photos).
  final int hidden;

  /// WHERE pictures and videos are (not extra space: they are already in
  /// photos / videos / screenshots): DCIM/Camera, WhatsApp media, Download.
  final int camera;
  final int whatsapp;
  final int downloads;

  int get used => (total - free).clamp(0, total);

  /// Everything that is not a picture or video of the gallery (nor hidden):
  /// apps, system, documents ... Never negative.
  int get other {
    final known = photos + videos + screenshots + trash + hidden;
    return (used - known).clamp(0, used);
  }

  /// The parts of the bar / ring, in order. A part is a share of [total].
  List<({StorageKind kind, int bytes})> get segments => [
    (kind: StorageKind.photos, bytes: photos),
    (kind: StorageKind.videos, bytes: videos),
    (kind: StorageKind.screenshots, bytes: screenshots),
    (kind: StorageKind.trash, bytes: trash),
    (kind: StorageKind.hidden, bytes: hidden),
    (kind: StorageKind.other, bytes: other),
  ];

  int bytesOf(StorageKind kind) => switch (kind) {
    StorageKind.photos => photos,
    StorageKind.videos => videos,
    StorageKind.screenshots => screenshots,
    StorageKind.trash => trash,
    StorageKind.hidden => hidden,
    StorageKind.other => other,
    StorageKind.free => free,
    StorageKind.camera => camera,
    StorageKind.whatsapp => whatsapp,
    StorageKind.downloads => downloads,
  };
}

/// What the storage holds. The last three are folders (where pictures and
/// videos are), shown as their own cards but not as parts of the ring.
enum StorageKind {
  photos,
  videos,
  screenshots,
  trash,
  hidden,
  other,
  free,
  camera,
  whatsapp,
  downloads,
}
