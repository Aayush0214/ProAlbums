import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';

/// Compressed copies in the app's own database (Drift).
final class DriftCompressedMediaRepository
    implements CompressedMediaRepository {
  const DriftCompressedMediaRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<Map<String, int>> watch() => _db
      .select(_db.compressedMedia)
      .watch()
      .map((rows) => {for (final row in rows) row.mediaId: row.sizeBytes});

  @override
  Future<void> remember(CompressedCopy copy) async {
    try {
      await _db
          .into(_db.compressedMedia)
          .insertOnConflictUpdate(
            CompressedMediaCompanion.insert(
              mediaId: copy.id,
              sizeBytes: copy.sizeBytes,
              createdAt: DateTime.now(),
            ),
          );
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not remember a compressed copy',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
