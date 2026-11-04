import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/cleanup/domain/cleanup_rules.dart';

const int _minute = 60 * 1000;

CleanupImage _image(
  String id, {
  int size = 1000,
  int width = 4000,
  int height = 3000,
  int takenMs = 0,
  int? dhash,
  double sharpness = 100,
  String? sha1,
}) => CleanupImage(
  id: id,
  size: size,
  width: width,
  height: height,
  takenMs: takenMs,
  dhash: dhash,
  sharpness: sharpness,
  sha1: sha1,
);

void main() {
  test('hamming distance counts differing bits (also the sign bit)', () {
    expect(hammingDistance(0, 0), 0);
    expect(hammingDistance(0, 7), 3);
    expect(hammingDistance(-1, 0), 64);
  });

  group('duplicates', () {
    test('only same size + dimensions need a file hash', () {
      final candidates = duplicateCandidates([
        _image('a', size: 100),
        _image('b', size: 100),
        _image('c', size: 200),
      ]);
      expect(candidates.map((i) => i.id), ['a', 'b']);
    });

    test('same file hash = one set; a different hash is not a copy', () {
      final groups = duplicateGroups([
        _image('a', sha1: 'x'),
        _image('b', sha1: 'x'),
        _image('c', sha1: 'y'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.map((i) => i.id), ['a', 'b']);
    });
  });

  group('similar', () {
    test('close in time and in look = one set', () {
      final groups = similarGroups([
        _image('a', takenMs: 0, dhash: 0x0F0F),
        _image('b', takenMs: _minute, dhash: 0x0F0E), // 1 bit away
        _image('c', takenMs: 2 * _minute, dhash: 0x7FFFFFFF), // far
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.map((i) => i.id), ['a', 'b']);
    });

    test('same look but hours apart is not similar', () {
      final groups = similarGroups([
        _image('a', takenMs: 0, dhash: 5),
        _image('b', takenMs: 120 * _minute, dhash: 5),
      ]);
      expect(groups, isEmpty);
    });

    test('exact copies are left to Duplicate images', () {
      final groups = similarGroups([
        _image('a', dhash: 5, sha1: 'same'),
        _image('b', dhash: 5, sha1: 'same'),
      ]);
      expect(groups, isEmpty);
    });

    test('newest set first', () {
      final groups = similarGroups([
        _image('old1', takenMs: 0, dhash: 1),
        _image('old2', takenMs: 1, dhash: 1),
        _image('new1', takenMs: 500 * _minute, dhash: 1),
        _image('new2', takenMs: 500 * _minute + 1, dhash: 1),
      ]);
      expect(groups.first.first.id, 'new1');
    });
  });

  group('smart recommendation keeps the best picture', () {
    test('the sharpest one', () {
      final best = bestOf([
        _image('blurred', sharpness: 20),
        _image('sharp', sharpness: 200),
      ]);
      expect(best.id, 'sharp');
    });

    test('about as sharp: more pixels, then the bigger file', () {
      expect(
        bestOf([
          _image('small', sharpness: 100, width: 1000, height: 1000),
          _image('big', sharpness: 98, width: 4000, height: 3000),
        ]).id,
        'big',
      );
      expect(
        bestOf([
          _image('light', sharpness: 100, size: 900),
          _image('heavy', sharpness: 100, size: 1200),
        ]).id,
        'heavy',
      );
    });
  });

  test('sizes read like the system gallery', () {
    expect(cleanupSize(2400000), '2.40 MB');
    expect(cleanupSize(446000), '446 KB');
    expect(cleanupSize(721000000), '721 MB');
  });
}
