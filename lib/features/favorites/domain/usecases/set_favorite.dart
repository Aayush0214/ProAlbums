import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/favorites/domain/repositories/favorites_repository.dart';

/// Heart on / off for one or many photos.
final class SetFavoriteUseCase {
  const SetFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  FutureResult<Unit> call(List<String> ids, {required bool value}) =>
      _repository.setFavorite(ids, value: value);
}
