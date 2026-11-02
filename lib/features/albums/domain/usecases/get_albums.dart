import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/repositories/album_repository.dart';

final class GetAlbumsUseCase {
  const GetAlbumsUseCase(this._repository);

  final AlbumRepository _repository;

  FutureResult<List<Album>> call() => _repository.getAlbums();
}
