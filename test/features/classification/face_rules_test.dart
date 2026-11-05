import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';

/// A length-1 vector pointing mostly along [axis], nudged by [noise].
Float32List face(int axis, {double noise = 0, int noiseAxis = 100}) {
  final v = Float32List(FaceRules.embeddingLength);
  v[axis] = 1;
  v[noiseAxis] = noise;
  return v;
}

void main() {
  test('embeddings survive the trip to bytes and back', () {
    final v = Float32List.fromList([0.5, -1.25, 3]);
    expect(embeddingFromBytes(embeddingToBytes(v)), v);
  });

  test('cosine: same 1, opposite -1, unrelated 0', () {
    expect(faceCosine(face(0), face(0)), closeTo(1, 1e-6));
    expect(faceCosine(face(0), face(1)), closeTo(0, 1e-6));
    final minus = Float32List(FaceRules.embeddingLength)..[0] = -2;
    expect(faceCosine(face(0), minus), closeTo(-1, 1e-6));
  });

  group('grouping', () {
    NewFace n(int id, Float32List e, {bool strong = true, String? picture}) =>
        (id: id, embedding: e, strong: strong, mediaId: picture ?? 'p$id');

    test('two faces of one picture are never one person', () {
      // Twins in one picture + one more picture of each.
      final result = groupFaces(const [], [
        n(1, face(0), picture: 'group'),
        n(2, face(0, noise: 0.05), picture: 'group'),
        n(3, face(0, noise: 0.1)),
        n(4, face(0, noise: 0.15)),
      ]);
      expect(result.personOfFace[1], isNot(result.personOfFace[2]));
    });

    test('3 close faces make a person; a lone face waits', () {
      final result = groupFaces(const [], [
        n(1, face(0)),
        n(2, face(0, noise: 0.2)),
        n(3, face(0, noise: 0.3, noiseAxis: 101)),
        n(4, face(1)),
      ]);
      expect(result.created, hasLength(1));
      expect(result.created.single.count, 3);
      expect(result.created.single.id, lessThan(0));
      expect(result.personOfFace[1], result.personOfFace[2]);
      expect(result.personOfFace[1], result.personOfFace[3]);
      expect(result.personOfFace.containsKey(4), isFalse);
    });

    test('a face too far for the group joins the new person next round', () {
      final result = groupFaces(const [], [
        n(1, face(0)),
        n(2, face(0, noise: 0.1)),
        n(3, face(0, noise: 0.1, noiseAxis: 101)),
        // cos ≈ 0.45 to each: not "near" (0.50), but score ≥ 0.40.
        n(4, face(0, noise: 2.0)),
      ]);
      expect(result.created.single.count, 4);
      expect(result.personOfFace[4], result.personOfFace[1]);
    });

    test('a look-alike PAIR does not make a person', () {
      final result = groupFaces(const [], [
        n(1, face(0)),
        n(2, face(0, noise: 0.2)),
      ]);
      expect(result.created, isEmpty);
      expect(result.personOfFace, isEmpty);
    });

    test('small faces never start a person', () {
      final result = groupFaces(const [], [
        for (var i = 0; i < 4; i++) n(i, face(0), strong: false),
      ]);
      expect(result.created, isEmpty);
    });

    test('a face joins the closest known person and moves its average', () {
      final known = [
        (id: 7, mean: face(0), count: 3),
        (id: 8, mean: face(1), count: 5),
      ];
      final result = groupFaces(known, [n(1, face(1, noise: 0.3))]);
      expect(result.personOfFace[1], 8);
      expect(result.created, isEmpty);
      final changed = result.changed.single;
      expect(changed.id, 8);
      expect(changed.count, 6);
      // The face counts as length 1: 0.3 / 1.044 / 6.
      expect(changed.mean[100], closeTo(0.0479, 1e-3));
    });

    test('a small face must be surer to join', () {
      // Score 0.42: enough for a big face, not for a small one.
      final known = [(id: 7, mean: face(0), count: 3)];
      final e = face(0, noise: 2.16); // cos ≈ 0.42
      expect(groupFaces(known, [n(1, e)]).personOfFace[1], 7);
      expect(groupFaces(known, [n(1, e, strong: false)]).personOfFace, isEmpty);
    });

    test('one look-alike face does not glue two people together', () {
      final bridge = Float32List(FaceRules.embeddingLength)
        ..[0] = 0.7071
        ..[1] = 0.7071; // cos 0.71 to both people
      final groups = averageGroups([
        face(0),
        face(0, noise: 0.1),
        face(0, noise: 0.2),
        bridge,
        face(1),
        face(1, noise: 0.1),
        face(1, noise: 0.2),
      ]);
      expect(groups, hasLength(2));
      expect(groups.map((g) => g.length).toList(), [4, 3]);
    });

    test('two different people stay two groups', () {
      final unit = [
        face(0),
        face(0, noise: 0.1),
        face(0, noise: 0.2),
        face(1),
        face(1, noise: 0.1),
        face(1, noise: 0.2),
      ];
      expect(averageGroups(unit), hasLength(2));
    });
  });

  group('People page', () {
    PersonStanding p(
      int id, {
      int pictures = 10,
      bool? shown,
      int changedAt = 0,
    }) => (id: id, shown: shown, pictures: pictures, changedAt: changedAt);

    test('the app shows people with enough pictures, most first', () {
      expect(
        peopleOnPage([
          p(1, pictures: 6),
          p(2, pictures: 40),
          p(3, pictures: 4),
        ]),
        [2, 1],
      );
    });

    test('at most the top ${FaceRules.maxAutoShown}', () {
      final many = [for (var i = 0; i < 30; i++) p(i, pictures: 100 - i)];
      final on = peopleOnPage(many);
      expect(on, hasLength(FaceRules.maxAutoShown));
      expect(on.first, 0);
    });

    test('hidden never, added always, changed ones first', () {
      final on = peopleOnPage([
        p(1, pictures: 50, shown: false),
        p(2, pictures: 1, shown: true, changedAt: 5),
        p(3, pictures: 30),
        p(4, pictures: 8, changedAt: 9),
      ]);
      expect(on, [4, 2, 3]);
    });
  });

  test('similar people: faces close on average, closest first', () {
    // A mean of length 0.7 = faces about 0.49 alike inside the group.
    Float32List mean(double along0, {double along2 = 0}) =>
        Float32List(FaceRules.embeddingLength)
          ..[0] = 0.7 * along0
          ..[2] = 0.7 * along2;
    final me = (id: 1, mean: mean(1), count: 4);
    final others = [
      (id: 2, mean: mean(0.8, along2: 0.6), count: 4), // 0.39
      (id: 3, mean: mean(1), count: 4), // 0.49: the same person split
      (id: 4, mean: mean(0.5, along2: 0.87), count: 4), // 0.25: someone else
    ];
    expect(similarPeople(me, others), [3, 2]);
  });

  test('a bigger, sharper face is a better cover', () {
    expect(
      faceQuality(size: 0.4, sharpness: 200),
      greaterThan(faceQuality(size: 0.1, sharpness: 200)),
    );
    expect(
      faceQuality(size: 0.3, sharpness: 400),
      greaterThan(faceQuality(size: 0.3, sharpness: 20)),
    );
  });

  group('featured pictures', () {
    const day = 24 * 60 * 60 * 1000;
    FeaturedCandidate f(String id, double quality, int dayIndex) =>
        (mediaId: id, quality: quality, takenMs: dayIndex * day + 1000);

    test('the best of each day first, then the rest; newest first', () {
      final chosen = featuredPictures([
        f('a', 0.9, 1),
        f('b', 0.8, 1), // same day as a, second best
        f('c', 0.2, 2),
        f('d', 0.1, 3),
      ], max: 3);
      // One per day wins over the second best of day 1.
      expect(chosen, ['d', 'c', 'a']);
    });

    test('fewer days than places: filled with the next best', () {
      final chosen = featuredPictures([
        f('a', 0.9, 1),
        f('b', 0.8, 1),
        f('c', 0.1, 1),
      ], max: 2);
      expect(chosen.toSet(), {'a', 'b'});
    });

    test('a picture with two faces of the person counts once', () {
      final chosen = featuredPictures([f('a', 0.9, 1), f('a', 0.4, 1)]);
      expect(chosen, ['a']);
    });
  });

  test('a person is shown like an album', () {
    expect(personIdOfAlbum(personAlbumId(42)), 42);
    expect(personIdOfAlbum('-1617409521'), isNull);
    expect(personIdOfAlbum(null), isNull);
  });
}
