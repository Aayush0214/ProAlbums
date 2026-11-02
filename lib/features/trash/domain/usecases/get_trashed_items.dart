import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// Everything in "Recently deleted".
final class GetTrashedItemsUseCase {
  const GetTrashedItemsUseCase(this._repository);

  final TrashRepository _repository;

  FutureResult<List<TrashedItem>> call() => _repository.getTrashed();
}
