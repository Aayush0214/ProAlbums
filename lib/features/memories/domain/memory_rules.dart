import 'dart:math' as math;

/// Numbers for Memories and Featured (change here only; tuned on the
/// phone against the system gallery).
abstract final class MemoryRules {
  /// A day with at least this many pictures is a memory.
  static const int dayMin = 12;

  /// A weekend (Saturday + Sunday, both with pictures).
  static const int weekendMin = 15;

  /// A month.
  static const int monthMin = 30;

  /// A trip: days with pictures at most [tripGapDays] apart, at least
  /// [tripMinDays] of them, [tripMin] pictures, mostly away from home.
  static const int tripMin = 20;
  static const int tripMinDays = 2;
  static const int tripGapDays = 1;

  /// A weekend / month mostly made of one day (or a trip) is not repeated
  /// as its own memory.
  static const double mostly = 0.8;

  /// One person over the years (the first [personTop] people of the People
  /// page), a group of people over the years, group photos over the years.
  static const int personMin = 20;
  static const int personTop = 5;
  static const int pastTimesMin = 15;
  static const int pastTimesTop = 10;
  static const int groupMin = 15;

  /// "Over the years" = pictures from at least this many years.
  static const int minYears = 2;

  /// Pictures a new memory shows (its video, View Gallery): the best,
  /// spread over its time (Aayush: 10–15, the rest are added by the user).
  static const int defaultShown = 15;

  /// At most this many can be shown (Gallery management, like the system
  /// gallery's "Shown (N/50)"); every other picture stays a candidate.
  static const int maxShown = 50;

  /// A memory the app makes by itself needs at least this many different
  /// moments (14 pictures of one burst are one moment: no memory).
  static const int minShown = 5;

  /// A person's memory asked for (the person page's ▶) needs only this
  /// many different pictures.
  static const int minPersonShown = 3;

  /// Pictures taken within this many seconds are one moment (only the best
  /// is shown).
  static const int burstSeconds = 30;

  /// Featured: the best picture of a day, with a face at least this big
  /// (share of the short side), newest first, at most [featuredMax].
  static const double featuredFace = 0.12;
  static const int featuredMax = 60;
}

/// The kinds of memories, in the order they are listed when equal.
enum MemoryKind { pastTimes, groupPhotos, person, trip, month, weekend, day }

/// A picture as Memories sees it (screenshots, documents and videos are
/// left out before).
typedef MemoryPhoto = ({
  String id,
  int takenMs,

  /// Town of the picture ("" = unknown).
  String place,

  /// People in it (person ids).
  Set<int> people,

  /// How good it looks (see [photoQuality]); 0 = no face.
  double quality,

  /// Biggest face (share of the short side), 0 = none.
  double biggestFace,

  /// Intelligent classification's "Group photo".
  bool groupPhoto,
});

/// A memory as the rules make it (saved by MemoryStore).
final class MemoryDraft {
  const MemoryDraft({
    required this.kind,
    required this.key,
    required this.title,
    required this.startMs,
    required this.endMs,
    required this.ids,
    required this.times,
    required this.shown,
    required this.coverId,
  });

  final MemoryKind kind;

  /// Stable name ("day:2025-10-22"): the same memory is found again on the
  /// next run (user edits and deletes stay).
  final String key;
  final String title;
  final int startMs;
  final int endMs;

  /// Every picture of the memory (candidates), oldest first.
  final List<String> ids;

  /// When each of [ids] was taken (ms).
  final List<int> times;

  /// The ones shown (at first [MemoryRules.defaultShown]), oldest first.
  final List<String> shown;
  final String coverId;

  MemoryDraft withCover(String id) => MemoryDraft(
    kind: kind,
    key: key,
    title: title,
    startMs: startMs,
    endMs: endMs,
    ids: ids,
    times: times,
    shown: shown,
    coverId: id,
  );
}

/// A person for memories: id, name (null = "People N"), place on the People
/// page (0 = first).
typedef MemoryPerson = ({int id, String? name});

/// How good a picture looks: its best face (size × log sharpness, like the
/// People covers); 0 without faces.
double photoQuality(List<({double size, double sharpness})> faces) {
  var best = 0.0;
  for (final f in faces) {
    final q = f.size * math.log(1 + math.max(0, f.sharpness));
    if (q > best) best = q;
  }
  return best;
}

DateTime _local(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

DateTime _dayOf(int ms) {
  final d = _local(ms);
  return DateTime(d.year, d.month, d.day);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Day titles like the system gallery's; one per day, always the same.
const List<String> _dayTitles = [
  'Highlights of the day',
  'Fine Day',
  'Freezing the moment',
];

int _years(Iterable<MemoryPhoto> photos) =>
    {for (final p in photos) _local(p.takenMs).year}.length;

/// Every memory of [photos] (see [MemoryRules]): multi-year ones first
/// (most pictures first), then the others newest first. [people] = the
/// People page in its order.
List<MemoryDraft> buildMemories(
  List<MemoryPhoto> photos, {
  List<MemoryPerson> people = const [],
}) {
  final sorted = [...photos]..sort((a, b) => a.takenMs.compareTo(b.takenMs));
  final byDay = <DateTime, List<MemoryPhoto>>{};
  for (final p in sorted) {
    (byDay[_dayOf(p.takenMs)] ??= []).add(p);
  }
  final days = byDay.keys.toList()..sort();
  final out = <MemoryDraft>[];

  // Trips first: their days, weekends and months are not repeated.
  final inTrip = <DateTime>{};
  for (final trip in _trips(days, byDay, sorted)) {
    inTrip.addAll(trip.days);
    out.add(
      _draft(
        MemoryKind.trip,
        'trip:${_dayKey(trip.days.first)}',
        trip.title,
        trip.photos,
      ),
    );
  }

  // Weekends: Saturday + Sunday, both with pictures, not mostly one day.
  final inWeekend = <DateTime>{};
  for (final saturday in days.where((d) => d.weekday == DateTime.saturday)) {
    final sunday = DateTime(saturday.year, saturday.month, saturday.day + 1);
    if (inTrip.contains(saturday) || inTrip.contains(sunday)) continue;
    final sat = byDay[saturday]!;
    final sun = byDay[sunday] ?? const <MemoryPhoto>[];
    final total = sat.length + sun.length;
    if (sun.isEmpty || total < MemoryRules.weekendMin) continue;
    if (math.max(sat.length, sun.length) >= total * MemoryRules.mostly) {
      continue;
    }
    inWeekend
      ..add(saturday)
      ..add(sunday);
    out.add(
      _draft(
        MemoryKind.weekend,
        'weekend:${_dayKey(saturday)}',
        'Weekend moments',
        [...sat, ...sun],
      ),
    );
  }

  // Days.
  for (final day in days) {
    final list = byDay[day]!;
    if (list.length < MemoryRules.dayMin) continue;
    if (inTrip.contains(day) || inWeekend.contains(day)) continue;
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    out.add(
      _draft(
        MemoryKind.day,
        'day:${_dayKey(day)}',
        _dayTitles[dayOfYear % _dayTitles.length],
        list,
      ),
    );
  }

  // Months: not when one day, a trip or a weekend is most of it.
  final byMonth = <DateTime, List<MemoryPhoto>>{};
  for (final p in sorted) {
    final d = _local(p.takenMs);
    (byMonth[DateTime(d.year, d.month)] ??= []).add(p);
  }
  for (final entry in byMonth.entries) {
    final list = entry.value;
    if (list.length < MemoryRules.monthMin) continue;
    final perDay = <DateTime, int>{};
    var covered = 0;
    for (final p in list) {
      final day = _dayOf(p.takenMs);
      perDay[day] = (perDay[day] ?? 0) + 1;
      if (inTrip.contains(day) || inWeekend.contains(day)) covered++;
    }
    final biggestDay = perDay.values.reduce(math.max);
    if (biggestDay >= list.length * MemoryRules.mostly ||
        covered >= list.length * MemoryRules.mostly) {
      continue;
    }
    final m = entry.key;
    final name = _monthNames[m.month - 1];
    final title = (m.year + m.month).isEven
        ? 'Encounter in $name'
        : 'Goodbye $name';
    out.add(
      _draft(MemoryKind.month, 'month:${m.year}-${_two(m.month)}', title, list),
    );
  }

  // One level per month: its special days / weekends when they hold at
  // least half of its pictures, else the month alone.
  String monthOf(MemoryDraft d) {
    final s = _local(d.startMs);
    return '${s.year}-${_two(s.month)}';
  }

  final drop = <MemoryDraft>{};
  for (final month in out.where((d) => d.kind == MemoryKind.month).toList()) {
    final inside = [
      for (final d in out)
        if ((d.kind == MemoryKind.day || d.kind == MemoryKind.weekend) &&
            monthOf(d) == monthOf(month))
          d,
    ];
    if (inside.isEmpty) continue;
    final covered = inside.fold<int>(0, (n, d) => n + d.ids.length);
    if (covered * 2 >= month.ids.length) {
      drop.add(month);
    } else {
      drop.addAll(inside);
    }
  }
  out.removeWhere(drop.contains);

  // Over the years.
  final multi = <MemoryDraft>[];
  final top = people.take(MemoryRules.personTop).toList();
  for (final (i, person) in top.indexed) {
    final list = [
      for (final p in sorted)
        if (p.people.contains(person.id)) p,
    ];
    if (list.length < MemoryRules.personMin ||
        _years(list) < MemoryRules.minYears) {
      continue;
    }
    multi.add(
      _draft(
        MemoryKind.person,
        'person:${person.id}',
        person.name ?? 'People ${i + 1}',
        list,
      ),
    );
  }

  final groups = [
    for (final p in sorted)
      if (p.groupPhoto) p,
  ];
  if (groups.length >= MemoryRules.groupMin &&
      _years(groups) >= MemoryRules.minYears) {
    multi.add(_draft(MemoryKind.groupPhotos, 'group', 'Group photos', groups));
  }

  final pair = _bestPair(sorted, people.take(MemoryRules.pastTimesTop));
  if (pair != null) {
    multi.add(
      _draft(
        MemoryKind.pastTimes,
        'past:${pair.a}-${pair.b}',
        'Past times',
        pair.photos,
      ),
    );
  }

  multi.sort((a, b) => b.ids.length.compareTo(a.ids.length));
  out.sort((a, b) => b.endMs.compareTo(a.endMs));
  // Covers: each memory takes its best shown picture that no memory
  // before it uses (one great close-up would else cover them all).
  final quality = {for (final p in sorted) p.id: p.quality};
  final usedCovers = <String>{};
  final result = <MemoryDraft>[];
  for (final m in [...multi, ...out]) {
    if (m.shown.length < MemoryRules.minShown) continue;
    final ranked = [...m.shown]
      ..sort((a, b) => (quality[b] ?? 0).compareTo(quality[a] ?? 0));
    final cover = ranked.firstWhere(
      (id) => !usedCovers.contains(id),
      orElse: () => ranked.first,
    );
    usedCovers.add(cover);
    result.add(m.withCover(cover));
  }
  return result;
}

typedef _Trip = ({List<DateTime> days, List<MemoryPhoto> photos, String title});

/// Runs of days close together, away from home (the town with the most
/// pictures), named after the town with the most pictures of the run.
List<_Trip> _trips(
  List<DateTime> days,
  Map<DateTime, List<MemoryPhoto>> byDay,
  List<MemoryPhoto> all,
) {
  final home = _mostCommonPlace(all);
  final out = <_Trip>[];
  var run = <DateTime>[];

  void close() {
    if (run.length >= MemoryRules.tripMinDays) {
      final photos = [for (final d in run) ...byDay[d]!];
      final placed = photos.where((p) => p.place.isNotEmpty).toList();
      final away = placed.where((p) => p.place != home).length;
      final place = _mostCommonPlace(placed.where((p) => p.place != home));
      if (photos.length >= MemoryRules.tripMin &&
          placed.isNotEmpty &&
          away * 2 >= placed.length &&
          place.isNotEmpty) {
        out.add((days: [...run], photos: photos, title: 'Trip to $place'));
      }
    }
    run = [];
  }

  for (final day in days) {
    if (run.isNotEmpty &&
        day.difference(run.last).inDays > MemoryRules.tripGapDays + 1) {
      close();
    }
    run.add(day);
  }
  close();
  return out;
}

String _mostCommonPlace(Iterable<MemoryPhoto> photos) {
  final counts = <String, int>{};
  for (final p in photos) {
    if (p.place.isEmpty) continue;
    counts[p.place] = (counts[p.place] ?? 0) + 1;
  }
  if (counts.isEmpty) return '';
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// The two people seen together most, if enough and over the years.
({int a, int b, List<MemoryPhoto> photos})? _bestPair(
  List<MemoryPhoto> photos,
  Iterable<MemoryPerson> people,
) {
  final ids = [for (final p in people) p.id];
  ({int a, int b, List<MemoryPhoto> photos})? best;
  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      final together = [
        for (final p in photos)
          if (p.people.contains(ids[i]) && p.people.contains(ids[j])) p,
      ];
      if (together.length < MemoryRules.pastTimesMin ||
          _years(together) < MemoryRules.minYears) {
        continue;
      }
      if (best == null || together.length > best.photos.length) {
        best = (a: ids[i], b: ids[j], photos: together);
      }
    }
  }
  return best;
}

MemoryDraft _draft(
  MemoryKind kind,
  String key,
  String title,
  List<MemoryPhoto> photos, {
  int burstSeconds = MemoryRules.burstSeconds,
}) {
  final sorted = [...photos]..sort((a, b) => a.takenMs.compareTo(b.takenMs));
  final shown = pickShown(sorted, burstSeconds: burstSeconds);
  final shownSet = shown.toSet();
  final cover = sorted
      .where((p) => shownSet.contains(p.id))
      .reduce((a, b) => b.quality > a.quality ? b : a);
  return MemoryDraft(
    kind: kind,
    key: key,
    title: title,
    startMs: sorted.first.takenMs,
    endMs: sorted.last.takenMs,
    ids: [for (final p in sorted) p.id],
    times: [for (final p in sorted) p.takenMs],
    shown: shown,
    coverId: cover.id,
  );
}

/// The pictures to show (oldest first): one per moment (pictures within
/// [burstSeconds] = the best of them; 0 = only pictures of the same second),
/// then, when still more than [max], the best of each equal slice of time.
List<String> pickShown(
  List<MemoryPhoto> photos, {
  int max = MemoryRules.defaultShown,
  int burstSeconds = MemoryRules.burstSeconds,
}) {
  final sorted = [...photos]..sort((a, b) => a.takenMs.compareTo(b.takenMs));
  final moments = <MemoryPhoto>[];
  for (final p in sorted) {
    if (moments.isNotEmpty &&
        p.takenMs - moments.last.takenMs <
            math.max(1000, burstSeconds * 1000)) {
      if (p.quality > moments.last.quality) moments.last = p;
      continue;
    }
    moments.add(p);
  }
  if (moments.length <= max) return [for (final p in moments) p.id];
  final out = <String>[];
  for (var i = 0; i < max; i++) {
    final from = i * moments.length ~/ max;
    final to = (i + 1) * moments.length ~/ max;
    out.add(
      moments
          .sublist(from, to)
          .reduce((a, b) => b.quality > a.quality ? b : a)
          .id,
    );
  }
  return out;
}

/// Featured: the best picture of each day that has a clear face, newest
/// first.
List<MemoryPhoto> featuredPhotos(List<MemoryPhoto> photos) {
  final best = <DateTime, MemoryPhoto>{};
  for (final p in photos) {
    if (p.biggestFace < MemoryRules.featuredFace) continue;
    final day = _dayOf(p.takenMs);
    final known = best[day];
    if (known == null || p.quality > known.quality) best[day] = p;
  }
  final list = best.values.toList()
    ..sort((a, b) => b.takenMs.compareTo(a.takenMs));
  return list.take(MemoryRules.featuredMax).toList();
}

/// The date line of a memory, like the system gallery:
///  - a person: years ("2021-2024");
///  - group photos / past times: months ("December 2021-December 2024");
///  - a month: "April 2026"; a day: "February 9, 2021";
///  - a weekend / trip: "May 3-4, 2025", "March 30-April 2, 2026",
///    "December 30, 2024-January 2, 2025".
String memoryDateText(MemoryKind kind, int startMs, int endMs) {
  final a = _local(startMs);
  final b = _local(endMs);
  String month(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
  String day(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
  switch (kind) {
    case MemoryKind.person:
      return a.year == b.year ? '${a.year}' : '${a.year}-${b.year}';
    case MemoryKind.groupPhotos:
    case MemoryKind.pastTimes:
      return month(a) == month(b) ? month(a) : '${month(a)}-${month(b)}';
    case MemoryKind.month:
      return month(a);
    case MemoryKind.day:
      return day(a);
    case MemoryKind.weekend:
    case MemoryKind.trip:
      if (a.year == b.year && a.month == b.month && a.day == b.day) {
        return day(a);
      }
      if (a.year != b.year) return '${day(a)}-${day(b)}';
      final from = '${_monthNames[a.month - 1]} ${a.day}';
      final to = a.month == b.month
          ? '${b.day}'
          : '${_monthNames[b.month - 1]} ${b.day}';
      return '$from-$to, ${a.year}';
  }
}

/// Featured's date line: "October 22, 2025".
String featuredDateText(int takenMs) {
  final d = _local(takenMs);
  return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
}

/// A memory's pictures are shown like an album (grid, viewer, actions).
String memoryAlbumId(int memoryId) => 'memory:$memoryId';

/// The memory of a [memoryAlbumId] (null = not a memory).
int? memoryIdOfAlbum(String? albumId) =>
    albumId != null && albumId.startsWith('memory:')
    ? int.tryParse(albumId.substring('memory:'.length))
    : null;

/// A person's memory made on request (the person page's ▶): every picture
/// of the person; only pictures of the same second count as one (a party's
/// pictures a few seconds apart all count). null = fewer than
/// [MemoryRules.minPersonShown] different pictures.
MemoryDraft? personMemory(
  int personId,
  String title,
  List<MemoryPhoto> photos,
) {
  if (photos.isEmpty) return null;
  final draft = _draft(
    MemoryKind.person,
    'person:$personId',
    title,
    photos,
    burstSeconds: 0,
  );
  return draft.shown.length < MemoryRules.minPersonShown ? null : draft;
}

/// The memory player's pace: each picture's fade in + time on screen.
const Duration memorySlide = Duration(milliseconds: 2400);
const Duration memoryFade = Duration(milliseconds: 800);
Duration get memoryPerPicture => memorySlide + memoryFade;
