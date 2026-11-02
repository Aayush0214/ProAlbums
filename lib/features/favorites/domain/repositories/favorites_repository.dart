import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/favorites/domain/entities/favorite_location.dart';

/// Which photos / videos have the heart.
abstract interface class FavoritesRepository {
  /// All favorite ids. Emits again every time one is added or removed.
  Stream<Set<String>> watchIds();

  /// All favorite ids right now (one look, no stream).
  Future<Set<String>> getIds();

  /// Put the heart on ([value] true) or take it off ([value] false).
  FutureResult<Unit> setFavorite(List<String> ids, {required bool value});

  /// Saves the file name + folder of favorites that have none yet (rows that
  /// already have them are left alone). Never throws: it is a best-effort
  /// extra for backup / restore.
  Future<void> saveLocations(List<FavoriteLocation> locations);
}
