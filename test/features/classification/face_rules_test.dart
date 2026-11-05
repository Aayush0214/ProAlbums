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
    test('close faces become one person, different faces two', () {
      final result = groupFaces(const [], [
        (id: 1, embedding: face(0)),
        (id: 2, embedding: face(0, noise: 0.2)),
        (id: 3, embedding: face(1)),
      ]);
      expect(result.created, hasLength(2));
      expect(result.personOfFace[1], result.personOfFace[2]);
      expect(result.personOfFace[3], isNot(result.personOfFace[1]));
      expect(result.created.every((p) => p.id < 0), isTrue);
    });

    test('a face joins the closest known person and moves its average', () {
      final known = [
        (id: 7, mean: face(0), count: 3),
        (id: 8, mean: face(1), count: 5),
      ];
      final result = groupFaces(known, [
        (id: 1, embedding: face(1, noise: 0.3)),
      ]);
      expect(result.personOfFace[1], 8);
      expect(result.created, isEmpty);
      final changed = result.changed.single;
      expect(changed.id, 8);
      expect(changed.count, 6);
      // The face counts as length 1: 0.3 / 1.044 / 6.
      expect(changed.mean[100], closeTo(0.0479, 1e-3));
    });

    test('too far from everyone starts a new person', () {
      final result = groupFaces(
        [(id: 7, mean: face(0), count: 3)],
        [(id: 1, embedding: face(2))],
      );
      expect(result.created.single.count, 1);
      expect(result.changed, isEmpty);
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

  test('similar people: close but not merged, closest first', () {
    final me = (id: 1, mean: face(0), count: 4);
    final others = [
      (id: 2, mean: face(0, noise: 1.5), count: 4), // cos ≈ 0.55
      (id: 3, mean: face(0, noise: 0.5), count: 4), // cos ≈ 0.89
      (id: 4, mean: face(5), count: 4), // unrelated
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
}
