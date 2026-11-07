import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';

var _n = 0;

/// [count] pictures on [day], one minute apart (one moment each).
List<MemoryPhoto> shots(
  DateTime day,
  int count, {
  String place = '',
  Set<int> people = const {},
  bool group = false,
  double quality = 1,
}) => [
  for (var i = 0; i < count; i++)
    (
      id: 'p${_n++}',
      takenMs: day.add(Duration(hours: 10, minutes: i)).millisecondsSinceEpoch,
      place: place,
      people: people,
      quality: quality,
      biggestFace: people.isEmpty ? 0 : 0.2,
      groupPhoto: group,
    ),
];

List<String> keys(List<MemoryDraft> memories) => [
  for (final m in memories) m.key,
];

void main() {
  test('a busy day is a memory, a quiet one is not', () {
    final memories = buildMemories([
      ...shots(DateTime(2025, 10, 22), 12),
      ...shots(DateTime(2025, 10, 23), 5),
    ]);
    expect(keys(memories), ['day:2025-10-22']);
    expect(memories.single.kind, MemoryKind.day);
    expect(memories.single.ids.length, 12);
  });

  test('a burst is one moment: no memory', () {
    final t = DateTime(2025, 3, 3, 10).millisecondsSinceEpoch;
    final burst = [
      for (var i = 0; i < 14; i++)
        (
          id: 'b$i',
          takenMs: t + i * 1000,
          place: '',
          people: const <int>{},
          quality: 1.0,
          biggestFace: 0.0,
          groupPhoto: false,
        ),
    ];
    expect(buildMemories(burst), isEmpty);
  });

  test('a weekend replaces its days; not when one day is most of it', () {
    // 2025-10-18 is a Saturday.
    final weekend = buildMemories([
      ...shots(DateTime(2025, 10, 18), 12),
      ...shots(DateTime(2025, 10, 19), 8),
    ]);
    expect(keys(weekend), ['weekend:2025-10-18']);
    expect(weekend.single.title, 'Weekend moments');

    final oneDay = buildMemories([
      ...shots(DateTime(2025, 10, 18), 20),
      ...shots(DateTime(2025, 10, 19), 2),
    ]);
    expect(keys(oneDay), ['day:2025-10-18']);
  });

  test('a trip away from home, named after the town', () {
    final memories = buildMemories([
      // Home: many pictures in Ambikapur on scattered days.
      for (var d = 1; d <= 30; d += 3)
        ...shots(DateTime(2025, 1, d), 4, place: 'Ambikapur'),
      ...shots(DateTime(2025, 4, 10), 12, place: 'Velas'),
      ...shots(DateTime(2025, 4, 11), 12, place: 'Velas'),
    ]);
    final trip = memories.firstWhere((m) => m.kind == MemoryKind.trip);
    expect(trip.title, 'Trip to Velas');
    expect(trip.ids.length, 24);
    // Its days are not repeated as days.
    expect(keys(memories), isNot(contains('day:2025-04-10')));
  });

  test('a month, not when one day is most of it', () {
    final month = buildMemories([
      for (var d = 1; d <= 28; d += 2) ...shots(DateTime(2026, 4, d), 3),
    ]);
    expect(keys(month), ['month:2026-04']);
    expect(month.single.title, 'Encounter in April');

    final oneDay = buildMemories([
      ...shots(DateTime(2025, 7, 5), 40),
      ...shots(DateTime(2025, 7, 20), 2),
    ]);
    expect(keys(oneDay), ['day:2025-07-05']);
  });

  test('one level per month: its special days, or the month alone', () {
    // A big day holds most of the month: the day stays, the month goes.
    final bigDay = buildMemories([
      ...shots(DateTime(2022, 4, 9), 25),
      for (var d = 12; d <= 28; d += 4) ...shots(DateTime(2022, 4, d), 3),
    ]);
    expect(keys(bigDay), ['day:2022-04-09']);

    // Pictures all over the month: the month stays, the small day goes.
    final spread = buildMemories([
      ...shots(DateTime(2022, 4, 9), 12),
      for (var d = 1; d <= 28; d += 2) ...shots(DateTime(2022, 4, d), 3),
    ]);
    expect(keys(spread), ['month:2022-04']);
  });

  test('a person over the years, unnamed = "People N"', () {
    final memories = buildMemories(
      [
        ...shots(DateTime(2021, 3, 1), 4, people: {7}),
        ...shots(DateTime(2022, 3, 1), 4, people: {7}),
        ...shots(DateTime(2024, 3, 1), 4, people: {7}),
        for (var d = 1; d <= 8; d++)
          ...shots(DateTime(2024, 5, d * 3), 1, people: {7}),
      ],
      people: [
        (id: 9, name: 'Gaurghat'),
        (id: 3, name: null),
        (id: 7, name: null),
      ],
    );
    final person = memories.firstWhere((m) => m.kind == MemoryKind.person);
    expect(person.title, 'People 3');
    expect(person.key, 'person:7');
  });

  test('one year of a person is not "over the years"', () {
    final memories = buildMemories(
      [
        for (var d = 1; d <= 25; d++)
          ...shots(DateTime(2024, 1, d), 1, people: {7}),
      ],
      people: [(id: 7, name: 'Aayush')],
    );
    expect(memories.where((m) => m.kind == MemoryKind.person), isEmpty);
  });

  test('group photos and past times (two people together) over the years', () {
    final memories = buildMemories(
      [
        for (final y in [2022, 2023, 2024])
          for (var d = 1; d <= 6; d++)
            ...shots(DateTime(y, 2, d * 4), 1, people: {1, 2}, group: true),
      ],
      people: [(id: 1, name: 'A'), (id: 2, name: 'B')],
    );
    expect(
      memories.map((m) => m.kind),
      containsAll([MemoryKind.groupPhotos, MemoryKind.pastTimes]),
    );
    final past = memories.firstWhere((m) => m.kind == MemoryKind.pastTimes);
    expect(past.title, 'Past times');
    expect(past.ids.length, 18);
  });

  test('multi-year memories first, then newest first', () {
    final memories = buildMemories([
      ...shots(DateTime(2021, 2, 9), 12),
      ...shots(DateTime(2025, 7, 9), 12),
      for (final y in [2022, 2023])
        for (var d = 1; d <= 10; d++)
          ...shots(DateTime(y, 3, d * 2), 1, group: true),
    ]);
    expect(keys(memories), ['group', 'day:2025-07-09', 'day:2021-02-09']);
  });

  group('shown pictures', () {
    test('one per moment: the best of a burst', () {
      final t = DateTime(2025, 1, 1, 10).millisecondsSinceEpoch;
      MemoryPhoto at(String id, int seconds, double q) => (
        id: id,
        takenMs: t + seconds * 1000,
        place: '',
        people: const {},
        quality: q,
        biggestFace: 0,
        groupPhoto: false,
      );
      expect(
        pickShown([
          at('a', 0, 1),
          at('b', 10, 3),
          at('c', 20, 2),
          at('d', 600, 1),
        ]),
        ['b', 'd'],
      );
    });

    test('at most 50, spread over the time, oldest first', () {
      final photos = shots(DateTime(2025, 1, 1), 200);
      final shown = pickShown(photos);
      expect(shown.length, MemoryRules.maxShown);
      expect(shown.first, photos.first.id);
    });

    test('the cover is the best shown picture', () {
      final photos = [
        ...shots(DateTime(2025, 6, 1), 11),
        ...shots(DateTime(2025, 6, 1, 1), 1, quality: 9),
      ];
      expect(buildMemories(photos).single.coverId, photos.last.id);
    });
  });

  test(
    'featured: best picture of each day with a clear face, newest first',
    () {
      final day1 = [
        ...shots(DateTime(2025, 5, 3), 2, people: {1}),
        ...shots(DateTime(2025, 5, 3, 2), 1, people: {1}, quality: 5),
      ];
      final day2 = shots(DateTime(2025, 10, 22), 1, people: {1});
      final noFace = shots(DateTime(2025, 11, 1), 3);
      final featured = featuredPhotos([...day1, ...day2, ...noFace]);
      expect([for (final p in featured) p.id], [day2.single.id, day1.last.id]);
    },
  );

  test('picture quality = its best face', () {
    expect(photoQuality(const []), 0);
    expect(
      photoQuality(const [
        (size: 0.1, sharpness: 100),
        (size: 0.3, sharpness: 100),
      ]),
      greaterThan(photoQuality(const [(size: 0.1, sharpness: 100)])),
    );
  });
}
