import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// Takes pictures / videos out of the trash (back in all their albums).
final class RestoreFromTrashUseCase {
  const RestoreFromTrashUseCase(this._repository);

  final TrashRepository _repository;

  FutureResult<TrashActionOutcome> call(List<MediaItem> items) =>
      _repository.restore(items);
}
