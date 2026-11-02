import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// Moves pictures / videos to the trash (not gone for good).
final class MoveToTrashUseCase {
  const MoveToTrashUseCase(this._repository);

  final TrashRepository _repository;

  FutureResult<TrashOutcome> call(List<MediaItem> items) =>
      _repository.moveToTrash(items);
}
