import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_edit_repository.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';

Future<Uint8List?> _load(String id, int size) async => null;

void main() {
  group('renameProblem', () {
    test('a normal name is fine', () {
      expect(renameProblem('Trip to Goa 2026'), isNull);
      expect(renameProblem('  IMG_1234  '), isNull);
    });

    test('empty, dot first, forbidden characters, too long', () {
      expect(renameProblem('   '), 'Enter a name');
      expect(renameProblem('.hidden'), 'A name cannot start with a dot');
      for (final bad in [
        'a/b',
        r'a\b',
        'a:b',
        'a*b',
        'a?b',
        'a"b',
        'a<b',
        'a>b',
        'a|b',
      ]) {
        expect(renameProblem(bad), isNotNull, reason: bad);
      }
      expect(renameProblem('x' * 201), 'This name is too long');
    });
  });

  test('baseNameOf keeps everything before the last dot', () {
    expect(baseNameOf('IMG_1234.jpg'), 'IMG_1234');
    expect(baseNameOf('my.trip.mp4'), 'my.trip');
    expect(baseNameOf('README'), 'README');
    expect(baseNameOf('.nomedia'), '.nomedia');
  });

  test('a changed photo gets a new thumbnail key', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final before = MediaThumbnailImage(id: 'rot-1', size: 256, load: _load);
    expect(before, MediaThumbnailImage(id: 'rot-1', size: 256, load: _load));

    MediaThumbnailImage.markChanged('rot-1');

    final after = MediaThumbnailImage(id: 'rot-1', size: 256, load: _load);
    expect(after, isNot(before));
    expect(after.revision, before.revision + 1);
    // Other photos keep their key.
    expect(
      MediaThumbnailImage(id: 'other', size: 256, load: _load).revision,
      0,
    );
  });
}
