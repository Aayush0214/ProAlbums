import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/favorites/domain/entities/favorite_location.dart';
import 'package:proalbums/features/favorites/domain/repositories/favorites_repository.dart';

/// Favorites in the app's own SQLite database (Drift).
final class DriftFavoritesRepository implements FavoritesRepository {
  const DriftFavoritesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<Set<String>> watchIds() => _db
      .select(_db.favorites)
      .watch()
      .map((rows) => {for (final row in rows) row.mediaId})
      // Saving a file name (saveLocations) also touches the table, but the
      // hearts did not change: do not tell the screens about it.
      .distinct((a, b) => a.length == b.length && a.containsAll(b));

  @override
  Future<Set<String>> getIds() async {
    final rows = await _db.select(_db.favorites).get();
    return {for (final row in rows) row.mediaId};
  }

  @override
  Future<void> saveLocations(List<FavoriteLocation> locations) async {
    if (locations.isEmpty) return;
    try {
      // Write only what is missing: a write (even one that changes nothing)
      // wakes every stream that watches the table.
      final missing = await (_db.select(_db.favorites)
            ..where(
              (row) =>
                  row.mediaId.isIn([for (final l in locations) l.mediaId]) &
                  row.displayName.isNull(),
            ))
          .map((row) => row.mediaId)
          .get();
      if (missing.isEmpty) return;
      final todo = missing.toSet();
      await _db.batch((batch) {
        for (final location in locations) {
          if (!todo.contains(location.mediaId)) continue;
          batch.update(
            _db.favorites,
            FavoritesCompanion(
              displayName: Value(location.displayName),
              relativePath: Value(location.relativePath),
            ),
            // Only rows that do not have a name yet.
            where: (row) =>
                row.mediaId.equals(location.mediaId) & row.displayName.isNull(),
          );
        }
      });
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not save favorite locations', error: error, stackTrace: stackTrace);
    }
  }

  @override
  FutureResult<Unit> setFavorite(
    List<String> ids, {
    required bool value,
  }) async {
    if (ids.isEmpty) return right<Failure, Unit>(unit);
    try {
      final now = DateTime.now();
      await _db.batch((batch) {
        if (value) {
          // Already a favorite? Leave it as it is (keeps the first date).
          batch.insertAll(
            _db.favorites,
            [
              for (final id in ids)
                FavoritesCompanion.insert(mediaId: id, addedAt: now),
            ],
            mode: InsertMode.insertOrIgnore,
          );
        } else {
          batch.deleteWhere(_db.favorites, (row) => row.mediaId.isIn(ids));
        }
      });
      return right<Failure, Unit>(unit);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not update favorites', error: error, stackTrace: stackTrace);
      return left<Failure, Unit>(
        const MediaFailure('Could not update favorites.'),
      );
    }
  }
}
