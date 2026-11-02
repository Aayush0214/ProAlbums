import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/data/repositories/exif_parsing.dart';

void main() {
  group('parseExifNumber', () {
    test('fractions', () {
      expect(parseExifNumber('179/100'), closeTo(1.79, 1e-9));
      expect(parseExifNumber('1/100'), closeTo(0.01, 1e-9));
    });
    test('plain and listed numbers', () {
      expect(parseExifNumber('26'), 26);
      expect(parseExifNumber('[167]'), 167);
      expect(parseExifNumber('0'), 0);
      expect(parseExifNumber('-1'), -1);
    });
    test('nothing useful gives null', () {
      expect(parseExifNumber(null), isNull);
      expect(parseExifNumber('none'), isNull);
      expect(parseExifNumber('5/0'), isNull);
    });
  });

  group('cameraNameOf', () {
    test('model then make', () {
      expect(cameraNameOf(model: 'iQOO Z9 5G', make: 'iQOO'), 'iQOO Z9 5G, iQOO');
    });
    test('the same word is shown once', () {
      expect(cameraNameOf(model: 'Pixel', make: 'pixel'), 'Pixel');
    });
    test('missing parts', () {
      expect(cameraNameOf(model: null, make: 'iQOO'), 'iQOO');
      expect(cameraNameOf(model: ' ', make: ''), isNull);
    });
  });
}
