import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Which kind of album this is. The first five are the albums every phone has
/// (shown at the top; Favorites only when something has a heart); the rest
/// are plain folders.
enum AlbumKind { all, camera, favorites, videos, screenshots, folder }

/// Ids of the two albums that are not a real folder.
const String kAllAlbumId = 'all';
const String kVideosAlbumId = 'videos';

/// The hearted photos / videos: not a folder, built from the favorites table.
const String kFavoritesAlbumId = 'favorites';

/// Id prefix of an album that exists only as an (empty) folder.
const String kEmptyFolderPrefix = 'folder:';

/// One album of the Albums tab: a folder (or "All" / "Videos") with its cover.
final class Album {
  const Album({
    required this.id,
    required this.name,
    required this.kind,
    required this.count,
    this.cover,
  });

  final String id;
  final String name;
  final AlbumKind kind;
  final int count;

  /// The newest item, shown as the album picture. null for an empty album.
  final MediaItem? cover;

  Album withCover(MediaItem cover) => Album(
        id: id,
        name: name,
        kind: kind,
        count: count,
        cover: cover,
      );
}
