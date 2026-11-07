import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';

/// Talks to PlaceChannel.kt.
abstract interface class PlaceScanner {
  /// May the app read where pictures were taken? (Asks once.)
  Future<bool> permission();
  Future<List<FaceListedImage>> listImages();

  /// id → (lat, lng), only for pictures with a GPS place.
  Future<Map<String, ({double lat, double lng})>> locations(List<String> ids);

  /// The address parts of a place, or null (no internet / no answer).
  Future<Map<String, String?>?> address(double lat, double lng);
}

final class MethodChannelPlaceScanner implements PlaceScanner {
  const MethodChannelPlaceScanner();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/places',
  );

  @override
  Future<bool> permission() async {
    try {
      return await _channel.invokeMethod<bool>('permission') ?? false;
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Place permission failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<List<FaceListedImage>> listImages() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listImages',
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            id: row['id']! as String,
            modified: (row['modified']! as num).toInt(),
            takenMs: (row['taken']! as num).toInt(),
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Place list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<Map<String, ({double lat, double lng})>> locations(
    List<String> ids,
  ) async {
    try {
      final map = await _channel.invokeMapMethod<String, List<Object?>>(
        'locations',
        {'ids': ids},
      );
      return {
        for (final entry in (map ?? const <String, List<Object?>>{}).entries)
          entry.key: (
            lat: (entry.value[0]! as num).toDouble(),
            lng: (entry.value[1]! as num).toDouble(),
          ),
      };
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Place locations failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  @override
  Future<Map<String, String?>?> address(double lat, double lng) async {
    try {
      final map = await _channel.invokeMapMethod<String, String?>('placeName', {
        'lat': lat,
        'lng': lng,
      });
      return map;
    } on Object catch (error, stackTrace) {
      AppLogger.e('Place name failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }
}

/// The remembered places (Drift).
final class PlaceStore {
  const PlaceStore(this._db);

  final AppDatabase _db;

  /// Read pictures: id → DATE_MODIFIED when read.
  Future<Map<String, int>> read() async {
    final rows = await _db.select(_db.photoLocations).get();
    return {for (final row in rows) row.mediaId: row.modified};
  }

  /// Saves what was read ([found]: pictures with a place; the others are
  /// remembered without one).
  Future<void> save(
    List<String> ids,
    Map<String, ({double lat, double lng})> found,
    Map<String, FaceListedImage> listed,
  ) async {
    if (ids.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.photoLocations, [
        for (final id in ids)
          PhotoLocationsCompanion.insert(
            mediaId: id,
            modified: listed[id]?.modified ?? 0,
            takenMs: listed[id]?.takenMs ?? 0,
            lat: Value(found[id]?.lat),
            lng: Value(found[id]?.lng),
          ),
      ]);
    });
  }

  /// Pictures that are gone (or changed).
  Future<void> forget(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, (i + 500).clamp(0, list.length));
      await (_db.delete(
        _db.photoLocations,
      )..where((p) => p.mediaId.isIn(chunk))).go();
    }
  }

  Future<List<PlacedPicture>> _placed() async {
    final rows = await (_db.select(
      _db.photoLocations,
    )..where((p) => p.lat.isNotNull() & p.lng.isNotNull())).get();
    return [
      for (final row in rows)
        (
          id: row.mediaId,
          takenMs: row.takenMs,
          cell: placeCellOf(row.lat!, row.lng!),
        ),
    ];
  }

  /// Squares with pictures that have no name yet (never asked, the Geocoder
  /// could not answer [PlaceRules.retryAfter] ago, or named before the
  /// viewer's place line existed).
  Future<List<String>> cellsToName(DateTime now) async {
    final cells = {for (final p in await _placed()) p.cell};
    final known = {
      for (final row in await _db.select(_db.placeNames).get()) row.cell: row,
    };
    final retryBefore = now
        .subtract(PlaceRules.retryAfter)
        .millisecondsSinceEpoch;
    final out = <String>[];
    for (final cell in cells) {
      final row = known[cell];
      if (row == null ||
          (row.name == null && row.checkedAt < retryBefore) ||
          (row.name != null && (row.label == null || row.area == null))) {
        out.add(cell);
      }
    }
    return out;
  }

  Future<void> saveName(
    String cell, {
    required String? name,
    required String? label,
    required String? area,
    required DateTime now,
  }) => _db
      .into(_db.placeNames)
      .insertOnConflictUpdate(
        PlaceNamesCompanion.insert(
          cell: cell,
          name: Value(name),
          label: Value(label),
          area: Value(area),
          checkedAt: now.millisecondsSinceEpoch,
        ),
      );

  /// The viewer's place line of a picture (null = no place / not named).
  Future<String?> labelOf(String mediaId) async {
    final row = await (_db.select(
      _db.photoLocations,
    )..where((p) => p.mediaId.equals(mediaId))).getSingleOrNull();
    if (row == null || row.lat == null || row.lng == null) return null;
    final name =
        await (_db.select(_db.placeNames)
              ..where((n) => n.cell.equals(placeCellOf(row.lat!, row.lng!))))
            .getSingleOrNull();
    return name?.label ?? name?.name;
  }

  /// The place albums (see [placeAlbums]).
  Future<List<PlaceAlbum>> albums() async {
    final names = {
      for (final row in await (_db.select(
        _db.placeNames,
      )..where((n) => n.name.isNotNull())).get())
        row.cell: row.name!,
    };
    return placeAlbums(await _placed(), names);
  }

  /// Search: every named picture with its place and neighbourhood ("" =
  /// none).
  Future<List<({String id, String place, String area})>> named() async {
    final names = {
      for (final row in await (_db.select(
        _db.placeNames,
      )..where((n) => n.name.isNotNull())).get())
        row.cell: row,
    };
    return [
      for (final p in await _placed())
        if (names[p.cell] case final row?)
          (id: p.id, place: row.name!, area: row.area ?? ''),
    ];
  }

  /// Totals (for the scan log).
  Future<({int pictures, int placed, int cells, int named})> counts() async {
    final all = await read();
    final placed = await _placed();
    final names = await _db.select(_db.placeNames).get();
    return (
      pictures: all.length,
      placed: placed.length,
      cells: {for (final p in placed) p.cell}.length,
      named: names.where((n) => n.name != null).length,
    );
  }
}
