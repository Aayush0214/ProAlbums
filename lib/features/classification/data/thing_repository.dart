import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';

/// Talks to LabelChannel.kt.
abstract interface class LabelScanner {
  Future<List<FaceListedImage>> listImages();

  /// id → stored label text ("" = nothing seen) and which camera ("front",
  /// "back", "" = unknown); unreadable pictures are left out.
  Future<Map<String, SeenPicture>> labels(List<String> ids);

  /// The viewer's [T]: each text line of a picture as [left, top, right,
  /// bottom], 0–1 of the upright picture (empty = none / unreadable).
  Future<List<List<double>>> textLines(String id);
}

/// What LabelChannel found in a picture.
typedef SeenPicture = ({
  String labels,
  String camera,
  int textChars,
  double textArea,
  bool screenshot,

  /// The text read (for Search).
  String words,
});

final class MethodChannelLabelScanner implements LabelScanner {
  const MethodChannelLabelScanner();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/labels',
  );

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
      AppLogger.e('Label list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<List<List<double>>> textLines(String id) async {
    try {
      final lines = await _channel.invokeListMethod<List<Object?>>(
        'textLines',
        {'id': id},
      );
      return [
        for (final line in lines ?? const <List<Object?>>[])
          if (line.length == 4) [for (final v in line) (v! as num).toDouble()],
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Text lines failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<Map<String, SeenPicture>> labels(List<String> ids) async {
    try {
      final map = await _channel.invokeMapMethod<String, Map<Object?, Object?>>(
        'labels',
        {'ids': ids},
      );
      return {
        for (final entry
            in (map ?? const <String, Map<Object?, Object?>>{}).entries)
          entry.key: (
            labels: entry.value['labels'] as String? ?? '',
            camera: entry.value['camera'] as String? ?? '',
            textChars: (entry.value['textChars'] as num? ?? 0).toInt(),
            textArea: (entry.value['textArea'] as num? ?? 0).toDouble(),
            screenshot: entry.value['screenshot'] as bool? ?? false,
            words: entry.value['text'] as String? ?? '',
          ),
      };
    } on Object catch (error, stackTrace) {
      AppLogger.e('Labels failed', error: error, stackTrace: stackTrace);
      return const {};
    }
  }
}

/// The remembered labels (Drift).
final class ThingStore {
  const ThingStore(this._db);

  final AppDatabase _db;

  /// Looked-at pictures: id → DATE_MODIFIED when looked at.
  Future<Map<String, int>> read() async {
    final rows = await (_db.selectOnly(
      _db.photoLabels,
    )..addColumns([_db.photoLabels.mediaId, _db.photoLabels.modified])).get();
    return {
      for (final row in rows)
        row.read(_db.photoLabels.mediaId)!: row.read(_db.photoLabels.modified)!,
    };
  }

  /// Saves what was seen; unreadable pictures are saved with no labels so
  /// they are not tried again (until the file changes).
  Future<void> save(
    List<String> ids,
    Map<String, SeenPicture> seen,
    Map<String, FaceListedImage> listed,
  ) async {
    if (ids.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.photoLabels, [
        for (final id in ids)
          PhotoLabelsCompanion.insert(
            mediaId: id,
            modified: listed[id]?.modified ?? 0,
            takenMs: listed[id]?.takenMs ?? 0,
            labels: seen[id]?.labels ?? '',
            camera: Value(seen[id]?.camera ?? ''),
            textChars: Value(seen[id]?.textChars ?? 0),
            textArea: Value(seen[id]?.textArea ?? 0),
            screenshot: Value(seen[id]?.screenshot ?? false),
            words: Value(seen[id]?.words ?? ''),
          ),
      ]);
    });
  }

  /// LabelChannel reads pictures differently now: forget every picture
  /// (all are looked at again; "Remove this type" choices stay).
  Future<void> resetAll() => _db.delete(_db.photoLabels).go();

  /// "Remove this type": these pictures leave [kind] (nothing is deleted).
  Future<void> remove(ThingKind kind, Iterable<String> ids) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.thingExclusions, [
        for (final id in ids)
          ThingExclusionsCompanion.insert(mediaId: id, kind: kind.name),
      ]);
    });
  }

  Future<Map<ThingKind, Set<String>>> _removed() async {
    final out = <ThingKind, Set<String>>{};
    for (final row in await _db.select(_db.thingExclusions).get()) {
      final kind = ThingKind.values
          .where((k) => k.name == row.kind)
          .firstOrNull;
      if (kind != null) (out[kind] ??= {}).add(row.mediaId);
    }
    return out;
  }

  /// Pictures that are gone (or changed).
  Future<void> forget(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, (i + 500).clamp(0, list.length));
      await (_db.delete(
        _db.photoLabels,
      )..where((p) => p.mediaId.isIn(chunk))).go();
    }
  }

  /// Every looked-at picture with something seen or a known camera.
  Future<List<LabeledPicture>> labeled() async {
    final rows =
        await (_db.select(_db.photoLabels)..where(
              (p) => p.labels.equals('').not() | p.camera.equals('').not(),
            ))
            .get();
    return [
      for (final row in rows)
        (
          id: row.mediaId,
          takenMs: row.takenMs,
          labels: row.labels,
          camera: row.camera,
          text: (
            chars: row.textChars,
            area: row.textArea,
            screenshot: row.screenshot,
          ),
        ),
    ];
  }

  /// Search: labels + text read of every looked-at picture.
  Future<List<({String id, String labels, String words})>> searchable() async {
    final rows =
        await (_db.selectOnly(_db.photoLabels)..addColumns([
              _db.photoLabels.mediaId,
              _db.photoLabels.labels,
              _db.photoLabels.words,
            ]))
            .get();
    return [
      for (final row in rows)
        (
          id: row.read(_db.photoLabels.mediaId)!,
          labels: row.read(_db.photoLabels.labels)!,
          words: row.read(_db.photoLabels.words)!,
        ),
    ];
  }

  /// How many characters the scan read in a picture (0 = none / not yet).
  Future<int> textCharsOf(String id) async {
    final row = await (_db.select(
      _db.photoLabels,
    )..where((p) => p.mediaId.equals(id))).getSingleOrNull();
    return row?.textChars ?? 0;
  }

  /// The pictures People found faces in (for Group photo / Selfie).
  Future<List<LabeledPicture>> withFaces() async {
    final rows = await (_db.selectOnly(_db.faceScans).join([
      innerJoin(_db.faces, _db.faces.mediaId.equalsExp(_db.faceScans.mediaId)),
    ])..addColumns([_db.faceScans.mediaId, _db.faceScans.takenMs])).get();
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row.read(_db.faceScans.mediaId)!))
          (
            id: row.read(_db.faceScans.mediaId)!,
            takenMs: row.read(_db.faceScans.takenMs)!,
            labels: '',
            camera: '',
            text: noText,
          ),
    ];
  }

  /// Faces per picture: how many, and the biggest one's size.
  Future<Map<String, FaceStats>> faceStats() async {
    final rows = await (_db.selectOnly(
      _db.faces,
    )..addColumns([_db.faces.mediaId, _db.faces.size])).get();
    final out = <String, FaceStats>{};
    for (final row in rows) {
      final id = row.read(_db.faces.mediaId)!;
      final size = row.read(_db.faces.size)!;
      final known = out[id];
      final clear = size >= ThingRules.clearFaceSize ? 1 : 0;
      out[id] = known == null
          ? (faces: 1, clear: clear, biggest: size)
          : (
              faces: known.faces + 1,
              clear: known.clear + clear,
              biggest: size > known.biggest ? size : known.biggest,
            );
    }
    return out;
  }

  /// The thing albums (see [thingAlbums]).
  Future<Map<ThingKind, List<ThingPicture>>> albums() async {
    final labeled = await this.labeled();
    final known = {for (final p in labeled) p.id};
    return thingAlbums(
      [
        ...labeled,
        // Pictures with faces but no labels still make Group photo.
        for (final p in await withFaces())
          if (!known.contains(p.id)) p,
      ],
      await faceStats(),
      removed: await _removed(),
    );
  }
}
