import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';

/// A picture as listed by the phone (before it is looked at).
typedef FaceListedImage = ({String id, int modified, int takenMs});

/// A face as FaceChannel.kt found it.
typedef FoundFace = ({
  double left,
  double top,
  double right,
  double bottom,
  double size,
  double sharpness,
  Uint8List embedding,
});

/// One looked-at picture and its faces (none = empty).
typedef AnalyzedImage = ({String id, List<FoundFace> faces});

/// Talks to FaceChannel.kt.
abstract interface class FaceScanner {
  Future<List<FaceListedImage>> listImages();
  Future<List<AnalyzedImage>> analyze(List<String> ids);
}

final class MethodChannelFaceScanner implements FaceScanner {
  const MethodChannelFaceScanner();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/faces',
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
      AppLogger.e('Faces list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<List<AnalyzedImage>> analyze(List<String> ids) async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'analyze',
        {'ids': ids},
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            id: row['id']! as String,
            faces: [
              for (final face
                  in (row['faces']! as List<Object?>)
                      .cast<Map<Object?, Object?>>())
                (
                  left: (face['left']! as num).toDouble(),
                  top: (face['top']! as num).toDouble(),
                  right: (face['right']! as num).toDouble(),
                  bottom: (face['bottom']! as num).toDouble(),
                  size: (face['size']! as num).toDouble(),
                  sharpness: (face['sharpness']! as num).toDouble(),
                  embedding: face['embedding']! as Uint8List,
                ),
            ],
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Faces analyze failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }
}

/// Top level, so the isolate gets only the numbers (a closure inside
/// [FaceStore] would try to send the database too).
Future<GroupResult> _groupInIsolate(
  List<GroupPerson> people,
  List<NewFace> faces,
) => Isolate.run(() => groupFaces(people, faces));

/// A face as the People pages need it (no embedding).
typedef StoredFace = ({
  int id,
  String mediaId,
  int personId,
  double left,
  double top,
  double right,
  double bottom,
  double quality,
  int takenMs,
});

/// A person with what the People pages show.
typedef PersonSummary = ({
  int id,
  String? name,
  bool? shown,
  int changedAt,
  int pictures,
  StoredFace cover,
});

/// The remembered faces and people (Drift).
final class FaceStore {
  const FaceStore(this._db);

  final AppDatabase _db;

  /// Looked-at pictures: id → DATE_MODIFIED when looked at.
  Future<Map<String, int>> scanned() async {
    final rows = await _db.select(_db.faceScans).get();
    return {for (final row in rows) row.mediaId: row.modified};
  }

  /// Saves what was found (a picture looked at again loses its old faces
  /// first — call [forget] for those before).
  Future<void> saveAnalyzed(
    List<AnalyzedImage> images,
    Map<String, FaceListedImage> listed,
  ) async {
    if (images.isEmpty) return;
    await _db.batch((batch) {
      batch
        ..insertAllOnConflictUpdate(_db.faceScans, [
          for (final image in images)
            FaceScansCompanion.insert(
              mediaId: image.id,
              modified: listed[image.id]?.modified ?? 0,
              takenMs: listed[image.id]?.takenMs ?? 0,
            ),
        ])
        ..insertAll(_db.faces, [
          for (final image in images)
            for (final face in image.faces)
              FacesCompanion.insert(
                mediaId: image.id,
                left: face.left,
                top: face.top,
                right: face.right,
                bottom: face.bottom,
                size: face.size,
                sharpness: face.sharpness,
                embedding: face.embedding,
              ),
        ]);
    });
  }

  /// Pictures that are gone (or changed): their faces go, and the people
  /// who had them are worked out again.
  Future<void> forget(Iterable<String> mediaIds) async {
    final ids = mediaIds.toList();
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      final touched = <int>{};
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, (i + 500).clamp(0, ids.length));
        final rows =
            await (_db.selectOnly(_db.faces)
                  ..addColumns([_db.faces.personId])
                  ..where(
                    _db.faces.mediaId.isIn(chunk) &
                        _db.faces.personId.isNotNull(),
                  ))
                .get();
        touched.addAll(rows.map((r) => r.read(_db.faces.personId)!));
        await (_db.delete(_db.faces)..where((f) => f.mediaId.isIn(chunk))).go();
        await (_db.delete(
          _db.faceScans,
        )..where((s) => s.mediaId.isIn(chunk))).go();
      }
      await _repair(touched);
    });
  }

  /// Gives every new face to a person (in an isolate). True when anything
  /// changed.
  Future<bool> groupNewFaces() async {
    final newRows =
        await (_db.select(_db.faces).join([
                innerJoin(
                  _db.faceScans,
                  _db.faceScans.mediaId.equalsExp(_db.faces.mediaId),
                ),
              ])
              ..where(_db.faces.grouped.equals(false))
              ..orderBy([OrderingTerm.desc(_db.faceScans.takenMs)]))
            .get();
    if (newRows.isEmpty) return false;
    final faces = [
      for (final row in newRows)
        (
          id: row.readTable(_db.faces).id,
          embedding: embeddingFromBytes(row.readTable(_db.faces).embedding),
        ),
    ];
    final people = [
      for (final p in await _db.select(_db.people).get())
        (id: p.id, mean: embeddingFromBytes(p.centroid), count: p.faceCount),
    ];
    final result = await _groupInIsolate(people, faces);

    await _db.transaction(() async {
      final realId = <int, int>{};
      for (final person in result.created) {
        realId[person.id] = await _db
            .into(_db.people)
            .insert(
              PeopleCompanion.insert(
                centroid: embeddingToBytes(person.mean),
                faceCount: person.count,
              ),
            );
      }
      for (final person in result.changed) {
        await (_db.update(
          _db.people,
        )..where((p) => p.id.equals(person.id))).write(
          PeopleCompanion(
            centroid: Value(embeddingToBytes(person.mean)),
            faceCount: Value(person.count),
          ),
        );
      }
      await _db.batch((batch) {
        for (final entry in result.personOfFace.entries) {
          batch.update(
            _db.faces,
            FacesCompanion(
              personId: Value(realId[entry.value] ?? entry.value),
              grouped: const Value(true),
            ),
            where: (f) => f.id.equals(entry.key),
          );
        }
      });
    });
    return true;
  }

  /// Every person with their picture count and cover face.
  Future<List<PersonSummary>> people() async {
    final faces = await _facesOfPeople();
    final rows = await _db.select(_db.people).get();
    final byPerson = <int, List<StoredFace>>{};
    for (final face in faces) {
      (byPerson[face.personId] ??= []).add(face);
    }
    return [
      for (final row in rows)
        if (byPerson[row.id] case final list? when list.isNotEmpty)
          (
            id: row.id,
            name: row.name,
            shown: row.shown,
            changedAt: row.changedAt,
            pictures: {for (final f in list) f.mediaId}.length,
            cover: list.firstWhere(
              (f) => f.id == row.coverFaceId,
              orElse: () =>
                  list.reduce((a, b) => a.quality >= b.quality ? a : b),
            ),
          ),
    ];
  }

  /// The faces of one person, newest picture first.
  Future<List<StoredFace>> facesOf(int personId) async =>
      _facesOfPeople(personId: personId);

  Future<List<StoredFace>> _facesOfPeople({int? personId}) async {
    final f = _db.faces;
    final query =
        _db.selectOnly(f).join([
            innerJoin(
              _db.faceScans,
              _db.faceScans.mediaId.equalsExp(f.mediaId),
            ),
          ])
          ..addColumns([
            f.id,
            f.mediaId,
            f.personId,
            f.left,
            f.top,
            f.right,
            f.bottom,
            f.size,
            f.sharpness,
            _db.faceScans.takenMs,
          ])
          ..where(
            personId == null
                ? f.personId.isNotNull()
                : f.personId.equals(personId),
          )
          ..orderBy([OrderingTerm.desc(_db.faceScans.takenMs)]);
    return [
      for (final row in await query.get())
        (
          id: row.read(f.id)!,
          mediaId: row.read(f.mediaId)!,
          personId: row.read(f.personId)!,
          left: row.read(f.left)!,
          top: row.read(f.top)!,
          right: row.read(f.right)!,
          bottom: row.read(f.bottom)!,
          quality: faceQuality(
            size: row.read(f.size)!,
            sharpness: row.read(f.sharpness)!,
          ),
          takenMs: row.read(_db.faceScans.takenMs)!,
        ),
    ];
  }

  /// "Add name" (empty = no name).
  Future<void> rename(int personId, String name) async {
    final trimmed = name.trim();
    await (_db.update(_db.people)..where((p) => p.id.equals(personId))).write(
      PeopleCompanion(
        name: Value(trimmed.isEmpty ? null : trimmed),
        changedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// "+" (true) / Hide (false) on the People page.
  Future<void> setShown(Iterable<int> personIds, {required bool shown}) async {
    await (_db.update(
      _db.people,
    )..where((p) => p.id.isIn(personIds.toList()))).write(
      PeopleCompanion(
        shown: Value(shown),
        changedAt: shown
            ? Value(DateTime.now().millisecondsSinceEpoch)
            : const Value.absent(),
      ),
    );
  }

  /// "Set as cover".
  Future<void> setCover(int personId, int faceId) async {
    await (_db.update(_db.people)..where((p) => p.id.equals(personId))).write(
      PeopleCompanion(
        coverFaceId: Value(faceId),
        changedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// "Merge": every face of [from] goes to [into]; [from] people are gone.
  Future<void> merge(Iterable<int> from, {required int into}) async {
    final others = from.where((id) => id != into).toList();
    if (others.isEmpty) return;
    await _db.transaction(() async {
      final named = await (_db.select(
        _db.people,
      )..where((p) => p.id.isIn([into, ...others]))).get();
      await (_db.update(_db.faces)..where((f) => f.personId.isIn(others)))
          .write(FacesCompanion(personId: Value(into)));
      await (_db.delete(_db.people)..where((p) => p.id.isIn(others))).go();
      // Keep a name when the kept person has none.
      final target = named.firstWhere((p) => p.id == into);
      final name =
          target.name ??
          named.map((p) => p.name).whereType<String>().firstOrNull;
      await (_db.update(_db.people)..where((p) => p.id.equals(into))).write(
        PeopleCompanion(
          name: Value(name),
          shown: const Value(true),
          changedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      await _repair({into});
    });
  }

  /// "Not this person": the faces of [personId] in these pictures leave
  /// that person for good (they are not given to anyone else).
  Future<void> removeFromPerson(int personId, Iterable<String> mediaIds) async {
    final ids = mediaIds.toList();
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      final faces = await (_db.select(
        _db.faces,
      )..where((f) => f.personId.equals(personId) & f.mediaId.isIn(ids))).get();
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.faceRejections, [
          for (final face in faces)
            FaceRejectionsCompanion.insert(faceId: face.id, personId: personId),
        ]);
      });
      await (_db.update(_db.faces)
            ..where((f) => f.personId.equals(personId) & f.mediaId.isIn(ids)))
          .write(const FacesCompanion(personId: Value(null)));
      await _repair({personId});
    });
  }

  /// Average face and count again from the faces; people left with no
  /// faces are gone; a cover face that left is forgotten.
  Future<void> _repair(Set<int> personIds) async {
    for (final id in personIds) {
      final faces = await (_db.select(
        _db.faces,
      )..where((f) => f.personId.equals(id))).get();
      if (faces.isEmpty) {
        await (_db.delete(_db.people)..where((p) => p.id.equals(id))).go();
        continue;
      }
      final mean = meanOf([
        for (final f in faces) embeddingFromBytes(f.embedding),
      ]);
      final faceIds = {for (final f in faces) f.id};
      final person = await (_db.select(
        _db.people,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      await (_db.update(_db.people)..where((p) => p.id.equals(id))).write(
        PeopleCompanion(
          centroid: Value(embeddingToBytes(mean)),
          faceCount: Value(faces.length),
          coverFaceId: faceIds.contains(person?.coverFaceId)
              ? const Value.absent()
              : const Value(null),
        ),
      );
    }
  }

  /// Every person's average face (for "Similar people have been detected").
  Future<List<GroupPerson>> means() async => [
    for (final p in await _db.select(_db.people).get())
      (id: p.id, mean: embeddingFromBytes(p.centroid), count: p.faceCount),
  ];

  /// The grouping rules changed: every face is grouped again from scratch
  /// (faces stay, people and "Not this person" go).
  Future<void> resetGrouping() async {
    await _db.transaction(() async {
      await _db.delete(_db.people).go();
      await _db.delete(_db.faceRejections).go();
      await _db
          .update(_db.faces)
          .write(
            const FacesCompanion(personId: Value(null), grouped: Value(false)),
          );
    });
  }

  /// How well a person's faces belong together: their average score to the
  /// person (see [personScore]) and the share of faces below 0.25 (likely
  /// someone else). For the scan log while tuning.
  Future<({double average, double strays})> cohesion(int personId) async {
    final faces = await (_db.select(
      _db.faces,
    )..where((f) => f.personId.equals(personId))).get();
    if (faces.isEmpty) return (average: 0.0, strays: 0.0);
    final vectors = [for (final f in faces) embeddingFromBytes(f.embedding)];
    final mean = meanOf(vectors);
    final scores = [for (final v in vectors) personScore(v, mean)];
    return (
      average: scores.reduce((a, b) => a + b) / scores.length,
      strays: scores.where((s) => s < 0.25).length / scores.length,
    );
  }

  /// Totals (for the scan log and tests).
  Future<({int pictures, int faces, int people})> counts() async {
    final pictures =
        await (_db.selectOnly(_db.faceScans)
              ..addColumns([_db.faceScans.mediaId.count()]))
            .map((r) => r.read(_db.faceScans.mediaId.count()) ?? 0)
            .getSingle();
    final faces =
        await (_db.selectOnly(_db.faces)..addColumns([_db.faces.id.count()]))
            .map((r) => r.read(_db.faces.id.count()) ?? 0)
            .getSingle();
    final people =
        await (_db.selectOnly(_db.people)..addColumns([_db.people.id.count()]))
            .map((r) => r.read(_db.people.id.count()) ?? 0)
            .getSingle();
    return (pictures: pictures, faces: faces, people: people);
  }
}
