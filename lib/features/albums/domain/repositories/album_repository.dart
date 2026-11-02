import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

abstract interface class AlbumRepository {
  /// Every album with its count and cover (empty folders are not listed).
  FutureResult<List<Album>> getAlbums();

  /// Everything inside one album, newest first.
  FutureResult<List<MediaItem>> getAlbumItems(String albumId);

  /// Only the newest [limit] pictures of one album, quickly, so a big album
  /// can show its first screens before [getAlbumItems] has read everything.
  /// Empty for Favorites / empty folders (their full load is already quick).
  FutureResult<List<MediaItem>> getFirstAlbumItems(
    String albumId, {
    required int limit,
  });

  /// One picture / video by its id (the saved album cover). null if gone.
  Future<MediaItem?> getMediaItem(String id);
}
