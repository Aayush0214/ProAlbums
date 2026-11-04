import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';

/// A picture as listed by the phone (before it is looked at).
typedef ListedImage = ({
  String id,
  int size,
  int width,
  int height,
  int takenMs,
  int modified,
});

/// What the phone found in a picture.
typedef Fingerprint = ({String id, int dhash, double sharpness});

/// One remembered fingerprint (see CleanupFingerprints).
typedef StoredFingerprint = ({
  int modified,
  int dhash,
  double sharpness,
  String? sha1,
});

/// Talks to CleanupChannel.kt.
abstract interface class CleanupScanner {
  Future<List<ListedImage>> listImages();
  Future<List<Fingerprint>> fingerprints(List<String> ids);
  Future<Map<String, String>> contentHashes(List<String> ids);
}

final class MethodChannelCleanupScanner implements CleanupScanner {
  const MethodChannelCleanupScanner();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/cleanup',
  );

  @override
  Future<List<ListedImage>> listImages() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listImages',
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            id: row['id']! as String,
            size: (row['size']! as num).toInt(),
            width: (row['width']! as num).toInt(),
            height: (row['height']! as num).toInt(),
            takenMs: (row['taken']! as num).toInt(),
            modified: (row['modified']! as num).toInt(),
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Cleanup list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<List<Fingerprint>> fingerprints(List<String> ids) async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'fingerprints',
        {'ids': ids},
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            id: row['id']! as String,
            dhash: (row['dhash']! as num).toInt(),
            sharpness: (row['sharpness']! as num).toDouble(),
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Cleanup fingerprints failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<Map<String, String>> contentHashes(List<String> ids) async {
    try {
      final map = await _channel.invokeMapMethod<String, String>(
        'contentHashes',
        {'ids': ids},
      );
      return map ?? const {};
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Cleanup hashes failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }
}

/// The remembered fingerprints (Drift), so each picture is looked at once.
final class CleanupFingerprintStore {
  const CleanupFingerprintStore(this._db);

  final AppDatabase _db;

  Future<Map<String, StoredFingerprint>> all() async {
    final rows = await _db.select(_db.cleanupFingerprints).get();
    return {
      for (final row in rows)
        row.mediaId: (
          modified: row.modified,
          dhash: row.dhash,
          sharpness: row.sharpness,
          sha1: row.sha1,
        ),
    };
  }

  Future<void> saveFingerprints(
    List<Fingerprint> fingerprints,
    Map<String, int> modifiedById,
  ) async {
    if (fingerprints.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.cleanupFingerprints, [
        for (final print in fingerprints)
          CleanupFingerprintsCompanion.insert(
            mediaId: print.id,
            modified: modifiedById[print.id] ?? 0,
            dhash: print.dhash,
            sharpness: print.sharpness,
          ),
      ]);
    });
  }

  Future<void> saveHashes(Map<String, String> hashes) async {
    if (hashes.isEmpty) return;
    await _db.batch((batch) {
      for (final entry in hashes.entries) {
        batch.update(
          _db.cleanupFingerprints,
          CleanupFingerprintsCompanion(sha1: Value(entry.value)),
          where: (row) => row.mediaId.equals(entry.key),
        );
      }
    });
  }

  /// Forget pictures that are gone.
  Future<void> forget(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (_db.delete(
      _db.cleanupFingerprints,
    )..where((row) => row.mediaId.isIn(list))).go();
  }
}
