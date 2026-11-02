import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/albums/domain/services/album_name.dart';

void main() {
  group('validateAlbumName', () {
    test('accepts a normal name', () {
      expect(validateAlbumName('Trip 2026', const ['Pictures']), isNull);
    });

    test('rejects empty and blank names', () {
      expect(validateAlbumName('', const []), isNotNull);
      expect(validateAlbumName('   ', const []), isNotNull);
    });

    test('rejects characters a folder cannot have', () {
      for (final bad in ['a/b', r'a\b', 'a:b', 'a*b', 'a?b', 'a"b', 'a<b']) {
        expect(validateAlbumName(bad, const []), isNotNull, reason: bad);
      }
    });

    test('rejects hidden-folder names and very long names', () {
      expect(validateAlbumName('.hidden', const []), isNotNull);
      expect(validateAlbumName('a' * 51, const []), isNotNull);
    });

    test('rejects a name that already exists, ignoring case and spaces', () {
      expect(validateAlbumName(' pictures ', const ['Pictures']), isNotNull);
    });
  });
}
