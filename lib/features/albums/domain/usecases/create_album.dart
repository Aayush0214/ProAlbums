import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/repositories/album_folder_repository.dart';

final class CreateAlbumUseCase {
  const CreateAlbumUseCase(this._repository);

  final AlbumFolderRepository _repository;

  FutureResult<CreateFolderOutcome> call(String name) =>
      _repository.createFolder(name.trim());
}
