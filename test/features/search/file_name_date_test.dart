import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/search/domain/file_name_date.dart';

void main() {
  final now = DateTime(2026, 11, 7);
  DateTime? read(String name) => dateFromFileName(name, now: now);

  test('camera names give the moment', () {
    expect(read('IMG_20210209_184207.jpg'), DateTime(2021, 2, 9, 18, 42, 7));
    expect(
      read('IMG_20210209_184207_123.webp'),
      DateTime(2021, 2, 9, 18, 42, 7),
    );
    expect(read('IMG20210209184207.jpg'), DateTime(2021, 2, 9, 18, 42, 7));
    expect(
      read('PXL_20230105_101010123.jpg'),
      DateTime(2023, 1, 5, 10, 10, 10),
    );
    expect(read('B612_20200301_090000_001.jpg'), DateTime(2020, 3, 1, 9));
  });

  test('WhatsApp names give the day, in their order', () {
    expect(read('IMG-20210209-WA0000.jpg'), DateTime(2021, 2, 9, 12));
    expect(read('IMG-20210209-WA0012.jpg'), DateTime(2021, 2, 9, 12, 0, 12));
  });

  test('ms since 1970', () {
    expect(
      read('photo_1612876327000.jpg'),
      DateTime.fromMillisecondsSinceEpoch(1612876327000),
    );
  });

  test('no date or an impossible one', () {
    expect(read('Snapchat-1234567890.jpg'), isNull);
    expect(read('DSC_0042.JPG'), isNull);
    expect(read('IMG_20211345_101010.jpg'), isNull);
    expect(read('IMG_20210231_101010.jpg'), isNull);
    expect(read('IMG_19990101_101010.jpg'), isNull);
    expect(read('IMG_20300101_101010.jpg'), isNull);
  });
}
