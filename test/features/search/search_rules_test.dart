import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';

SearchMedia media(
  String id, {
  String name = 'IMG.jpg',
  String album = 'Camera',
  DateTime? taken,
  bool video = false,
}) => (
  id: id,
  name: name,
  album: album,
  takenMs: (taken ?? DateTime(2024, 1, 1)).millisecondsSinceEpoch,
  video: video,
  width: 100,
  height: 100,
  durationMs: 0,
);

void main() {
  final index = SearchIndex(
    media: [
      media('1', taken: DateTime(2023, 10, 5), name: 'IMG_om.jpg'),
      media('2', taken: DateTime(2024, 3, 1), album: 'WhatsApp Images'),
      media('3', taken: DateTime(2022, 10, 9)),
      media('4', taken: DateTime(2025, 6, 1), video: true),
    ],
    people: [
      (key: '7', title: 'Gaurghat', ids: ['1', '2']),
    ],
    places: [
      (key: 'Omkareshwar', title: 'Omkareshwar', ids: ['1', '3']),
      (key: 'Pimpri-Chinchwad', title: 'Pimpri-Chinchwad', ids: ['2']),
    ],
    areas: [
      (key: 'area:Chingrajpara', title: 'Chingrajpara', ids: ['4']),
      // Same as a town: not shown twice.
      (key: 'area:Omkareshwar', title: 'Omkareshwar', ids: ['1']),
    ],
    types: [
      (key: 'documents', title: 'Documents', ids: ['3']),
      (key: 'food', title: 'Food', ids: ['2']),
    ],
    labels: {
      '1': 'Smile:0.9,Comics:0.8',
      '2': 'Food:0.95,Smile:0.75',
      '3': 'Shoe:0.6',
      'gone': 'Smile:0.9',
    },
    words: {'2': 'one-pot high protein diet', '3': 'machine room'},
  );

  test('the query is trimmed, lower case, one space apart', () {
    expect(normalizeQuery('  October   2023 '), 'october 2023');
  });

  test('empty query finds nothing', () {
    expect(index.search('  '), isEmpty);
  });

  test('labels match from the start of a word only', () {
    expect(startsAWord('Fast food', 'foo'), isTrue);
    expect(startsAWord('Comics', 'com'), isTrue);
    expect(startsAWord('Community', 'om'), isFalse);
    expect(index.search('comi').single.title, 'Comics');
  });

  test('"om" finds places, text and file names (newest first)', () {
    final groups = index.search('om');
    expect(
      [for (final g in groups) (g.kind, g.title)],
      [
        (SearchKind.place, 'Omkareshwar'),
        (SearchKind.text, 'om'),
        (SearchKind.fileName, 'om'),
      ],
    );
    expect(groups.first.ids, ['1', '3']);
    expect(index.allOf(groups), ['1', '3']);
  });

  test('neighbourhoods are places; a town is not listed twice', () {
    final places = index
        .search('chin')
        .where((g) => g.kind == SearchKind.place)
        .map((g) => g.title);
    expect(places, ['Pimpri-Chinchwad', 'Chingrajpara']);
    expect(
      index.search('omkar').where((g) => g.kind == SearchKind.place).length,
      1,
    );
  });

  test('named people, albums', () {
    expect(index.search('gaur').single.kind, SearchKind.person);
    expect(index.search('whatsapp').single.title, 'WhatsApp Images');
  });

  test('a type is not repeated as a label; unsure labels do not count', () {
    final food = index.search('food');
    expect(food.where((g) => g.kind == SearchKind.type).single.key, 'food');
    expect(index.search('shoe'), isEmpty);
  });

  test('gone pictures are left out', () {
    expect(index.search('smile').single.ids, ['2', '1']);
  });

  group('dates', () {
    test('a year, a month (every year), both', () {
      expect(parseSearchDate('2023')!.title, '2023');
      expect(parseSearchDate('oct')!.title, 'October');
      expect(parseSearchDate('2023 oct')!.title, 'October 2023');
      expect(parseSearchDate('oc'), isNull);
      expect(parseSearchDate('om'), isNull);
      expect(parseSearchDate('12'), isNull);
    });

    test('searching a month finds that month of every year', () {
      final date = index
          .search('october')
          .where((g) => g.kind == SearchKind.date)
          .single;
      expect(date.ids, ['1', '3']);
      expect(
        index
            .search('october 2022')
            .singleWhere((g) => g.kind == SearchKind.date)
            .ids,
        ['3'],
      );
    });
  });

  group('chips', () {
    final all = ['4', '2', '1', '3'];

    test('years newest first, then the most common labels', () {
      expect(chipsFor(all, index), [
        (year: true, value: '2025'),
        (year: true, value: '2024'),
        (year: true, value: '2023'),
        (year: true, value: '2022'),
        (year: false, value: 'Smile'),
        (year: false, value: 'Comics'),
        (year: false, value: 'Food'),
      ]);
    });

    test('years: any of them; labels: all of them', () {
      expect(
        filterByChips(all, {
          (year: true, value: '2023'),
          (year: true, value: '2024'),
        }, index),
        ['2', '1'],
      );
      expect(
        filterByChips(all, {
          (year: true, value: '2023'),
          (year: false, value: 'Smile'),
        }, index),
        ['1'],
      );
      expect(
        filterByChips(all, {
          (year: false, value: 'Smile'),
          (year: false, value: 'Food'),
        }, index),
        ['2'],
      );
      expect(filterByChips(all, {}, index), all);
    });
  });

  test(
    'recent searches: newest first, exact repeats move up, at most maxRecent',
    () {
      expect(addRecentSearch(['a', 'b'], 'b'), ['b', 'a']);
      expect(addRecentSearch(['patna'], 'Patna'), ['Patna', 'patna']);
      expect(addRecentSearch(['a'], '  '), ['a']);
      expect(
        addRecentSearch([for (var i = 0; i < 10; i++) '$i'], 'x').length,
        SearchRules.maxRecent,
      );
    },
  );
}
