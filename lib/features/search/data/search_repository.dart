import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A library item as MediaStore lists it: [dated] = MediaStore knows when
/// it was taken (else [SearchMedia.takenMs] is when it was added, and the
/// real date may be in the EXIF).
typedef ListedMedia = ({SearchMedia media, bool dated, int modified});

/// The library as Search needs it (SearchChannel.kt) + recent searches.
abstract interface class SearchRepository {
  /// Every picture and video (not in the trash), newest first.
  Future<List<ListedMedia>> listMedia();

  /// When pictures were taken, from their EXIF (id → ms; no date = left
  /// out).
  Future<Map<String, int>> exifDates(List<String> ids);

  Future<List<String>> recentSearches();

  Future<void> saveRecentSearches(List<String> recent);
}

final class DeviceSearchRepository implements SearchRepository {
  const DeviceSearchRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/search',
  );

  static const String _recentKey = 'search_recent';

  @override
  Future<List<ListedMedia>> listMedia() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listMedia',
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            media: (
              id: row['id']! as String,
              name: row['name'] as String? ?? '',
              album: row['album'] as String? ?? '',
              takenMs: (row['taken']! as num).toInt(),
              video: row['video'] as bool? ?? false,
              width: (row['w'] as num? ?? 0).toInt(),
              height: (row['h'] as num? ?? 0).toInt(),
              durationMs: (row['duration'] as num? ?? 0).toInt(),
            ),
            dated: row['dated'] as bool? ?? true,
            modified: (row['modified'] as num? ?? 0).toInt(),
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Search list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<Map<String, int>> exifDates(List<String> ids) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'exifDates',
        {'ids': ids},
      );
      return {
        for (final entry in (map ?? const <String, Object?>{}).entries)
          if (entry.value case final num ms) entry.key: ms.toInt(),
      };
    } on Object catch (error, stackTrace) {
      AppLogger.e('EXIF dates failed', error: error, stackTrace: stackTrace);
      return const {};
    }
  }

  @override
  Future<List<String>> recentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  @override
  Future<void> saveRecentSearches(List<String> recent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, recent);
  }
}

/// The EXIF dates already read (Drift).
final class PhotoDateStore {
  const PhotoDateStore(this._db);

  final AppDatabase _db;

  /// id → (DATE_MODIFIED when read, date or null).
  Future<Map<String, ({int modified, int? takenMs})>> read() async => {
    for (final row in await _db.select(_db.photoDates).get())
      row.mediaId: (modified: row.modified, takenMs: row.takenMs),
  };

  /// Saves what was read for [ids] ([found] = the ones with a date).
  Future<void> save(
    List<String> ids,
    Map<String, int> found,
    Map<String, int> modifiedOf,
  ) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.photoDates, [
      for (final id in ids)
        PhotoDatesCompanion.insert(
          mediaId: id,
          modified: modifiedOf[id] ?? 0,
          takenMs: Value(found[id]),
        ),
    ]);
  });
}
