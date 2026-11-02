import 'package:proalbums/features/albums/domain/entities/album.dart';

/// The parts of the Albums tab.
final class AlbumSections {
  const AlbumSections({
    required this.top,
    required this.more,
    this.other = const [],
  });

  /// All, Camera, Favorites, Videos, Screenshots (when they exist).
  final List<Album> top;

  /// "More albums": EVERY folder the person did not send to "Other albums".
  /// New albums always land here.
  final List<Album> more;

  /// The folders the person sent to "Other albums" (empty = no such tile).
  final List<Album> other;
}

/// The kind of an album from its name (Android calls the camera folder
/// "Camera" and the screenshot folder "Screenshots").
AlbumKind albumKindOf({required bool isAll, required String name}) {
  if (isAll) return AlbumKind.all;
  return switch (name.trim().toLowerCase()) {
    'camera' => AlbumKind.camera,
    'screenshots' || 'screenshot' => AlbumKind.screenshots,
    _ => AlbumKind.folder,
  };
}

/// Puts the albums in the order of the system gallery: All, Camera, Favorites,
/// Videos, Screenshots on top, and the other folders by name under "More albums".
AlbumSections splitAlbums(
  List<Album> albums, {
  Set<String> movedToOthers = const {},
}) {
  const order = [
    AlbumKind.all,
    AlbumKind.camera,
    AlbumKind.favorites,
    AlbumKind.videos,
    AlbumKind.screenshots,
  ];
  final top = <Album>[
    for (final kind in order)
      ...albums.where((album) => album.kind == kind),
  ];
  final more = albums.where((album) => album.kind == AlbumKind.folder).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  // "Other albums" only holds what the person sent there (select an album,
  // "Move to Others"). Everything else stays in "More albums", however many.
  return AlbumSections(
    top: top,
    more: [for (final a in more) if (!movedToOthers.contains(a.name)) a],
    other: [for (final a in more) if (movedToOthers.contains(a.name)) a],
  );
}
