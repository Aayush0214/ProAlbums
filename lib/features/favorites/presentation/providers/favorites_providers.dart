import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/features/favorites/data/repositories/drift_favorites_repository.dart';
import 'package:proalbums/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:proalbums/features/favorites/domain/usecases/set_favorite.dart';
import 'package:proalbums/features/favorites/domain/usecases/watch_favorite_ids.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites_providers.g.dart';

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) =>
    DriftFavoritesRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
SetFavoriteUseCase setFavoriteUseCase(Ref ref) =>
    SetFavoriteUseCase(ref.watch(favoritesRepositoryProvider));

@Riverpod(keepAlive: true)
WatchFavoriteIdsUseCase watchFavoriteIdsUseCase(Ref ref) =>
    WatchFavoriteIdsUseCase(ref.watch(favoritesRepositoryProvider));

/// Every favorite id. Ask a single photo with
/// `ref.watch(favoriteIdsProvider.select((ids) => ids.value?.contains(id) ?? false))`
/// so only that heart rebuilds when something changes.
@Riverpod(keepAlive: true)
Stream<Set<String>> favoriteIds(Ref ref) =>
    ref.watch(watchFavoriteIdsUseCaseProvider)();
