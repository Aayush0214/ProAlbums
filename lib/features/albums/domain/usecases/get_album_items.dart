import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/repositories/album_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

final class GetAlbumItemsUseCase {
  const GetAlbumItemsUseCase(this._repository);

  final AlbumRepository _repository;

  FutureResult<List<MediaItem>> call(String albumId) =>
      _repository.getAlbumItems(albumId);

  /// Just the newest [limit] pictures, for a quick first screen.
  FutureResult<List<MediaItem>> first(String albumId, {int limit = 300}) =>
      _repository.getFirstAlbumItems(albumId, limit: limit);
}
