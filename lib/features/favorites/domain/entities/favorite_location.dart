/// Where a favorite lives on the phone: its file name and folder.
///
/// The media id can change after a reinstall or on a new phone; the name +
/// folder lets a backup find the same file again.
final class FavoriteLocation {
  const FavoriteLocation({
    required this.mediaId,
    required this.displayName,
    required this.relativePath,
  });

  final String mediaId;
  final String displayName;

  /// "DCIM/Camera/"
  final String relativePath;
}
