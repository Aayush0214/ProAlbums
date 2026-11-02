import 'package:proalbums/features/favorites/domain/repositories/favorites_repository.dart';

/// The set of favorite ids, kept up to date.
final class WatchFavoriteIdsUseCase {
  const WatchFavoriteIdsUseCase(this._repository);

  final FavoritesRepository _repository;

  Stream<Set<String>> call() => _repository.watchIds();
}
