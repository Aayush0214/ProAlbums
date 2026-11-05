import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';

FoundFace found(int axis, {double size = 0.3, double sharpness = 100}) {
  final v = Float32List(FaceRules.embeddingLength)..[axis] = 1;
  return (
    left: 0.1,
    top: 0.1,
    right: 0.4,
    bottom: 0.5,
    size: size,
    sharpness: sharpness,
    embedding: embeddingToBytes(v),
  );
}

void main() {
  late AppDatabase db;
  late FaceStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = FaceStore(db);
  });

  tearDown(() => db.close());

  Map<String, FaceListedImage> listed(List<String> ids) => {
    for (final (i, id) in ids.indexed)
      id: (id: id, modified: 1, takenMs: 1000 - i),
  };

  /// Pictures a1..a3 show person A (axis 0), b1 person B (axis 1).
  Future<void> seed() async {
    await store.saveAnalyzed([
      (id: 'a1', faces: [found(0)]),
      (id: 'a2', faces: [found(0, size: 0.6)]),
      (id: 'a3', faces: [found(0), found(1)]),
      (id: 'b1', faces: [found(1)]),
      (id: 'none', faces: const []),
    ], listed(['a1', 'a2', 'a3', 'b1', 'none']));
    expect(await store.groupNewFaces(), isTrue);
  }

  test('pictures are remembered with their modified time', () async {
    await seed();
    expect((await store.scanned()).keys, containsAll(['a1', 'none']));
  });

  test('faces are grouped into people with picture counts', () async {
    await seed();
    final people = await store.people();
    expect(people, hasLength(2));
    final a = people.firstWhere((p) => p.pictures == 3);
    // The biggest face is the cover.
    expect(a.cover.mediaId, 'a2');
    expect(people.map((p) => p.pictures), containsAll([3, 2]));
    // Nothing new: grouping again changes nothing.
    expect(await store.groupNewFaces(), isFalse);
  });

  test('name, cover and merge', () async {
    await seed();
    final people = await store.people();
    final a = people.firstWhere((p) => p.pictures == 3);
    final b = people.firstWhere((p) => p.pictures == 2);

    await store.rename(b.id, '  Ravi ');
    final faceA1 = (await store.facesOf(a.id))
        .firstWhere((f) => f.mediaId == 'a1');
    await store.setCover(a.id, faceA1.id);
    expect(
      (await store.people()).firstWhere((p) => p.id == a.id).cover.mediaId,
      'a1',
    );

    await store.merge([b.id], into: a.id);
    final after = await store.people();
    expect(after, hasLength(1));
    expect(after.single.id, a.id);
    expect(after.single.name, 'Ravi'); // the name is kept
    expect(after.single.pictures, 4);
    expect(after.single.shown, isTrue);
  });

  test('"Not this person" takes the picture out for good', () async {
    await seed();
    final a = (await store.people()).firstWhere((p) => p.pictures == 3);
    await store.removeFromPerson(a.id, ['a1']);
    expect((await store.people()).firstWhere((p) => p.id == a.id).pictures, 2);
    // Not given to anyone again.
    expect(await store.groupNewFaces(), isFalse);
  });

  test('deleted pictures leave; empty people are gone', () async {
    await seed();
    await store.forget(['b1', 'a3']);
    final people = await store.people();
    expect(people, hasLength(1));
    expect(people.single.pictures, 2);
    expect((await store.scanned()).containsKey('b1'), isFalse);
    expect((await store.counts()).people, 1);
  });

  test('hide and add', () async {
    await seed();
    final ids = [for (final p in await store.people()) p.id];
    await store.setShown(ids, shown: false);
    expect((await store.people()).every((p) => p.shown == false), isTrue);
    await store.setShown([ids.first], shown: true);
    final shown = (await store.people()).firstWhere((p) => p.id == ids.first);
    expect(shown.shown, isTrue);
    expect(shown.changedAt, greaterThan(0));
  });
}
