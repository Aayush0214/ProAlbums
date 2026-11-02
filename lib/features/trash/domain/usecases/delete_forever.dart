import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// Deletes pictures / videos for good (cannot be undone).
final class DeleteForeverUseCase {
  const DeleteForeverUseCase(this._repository);

  final TrashRepository _repository;

  FutureResult<TrashActionOutcome> call(List<MediaItem> items) =>
      _repository.deleteForever(items);
}
