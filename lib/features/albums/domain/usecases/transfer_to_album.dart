import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/domain/repositories/album_folder_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Copy or Move pictures / videos into an album (a real folder).
final class TransferToAlbumUseCase {
  const TransferToAlbumUseCase(this._repository);

  final AlbumFolderRepository _repository;

  FutureResult<TransferResult> call(
    List<MediaItem> items,
    TransferTarget target, {
    required bool move,
  }) =>
      _repository.transfer(items, target, move: move);
}
