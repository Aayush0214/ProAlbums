/// Numbers for Search (change here only).
abstract final class SearchRules {
  /// An ML Kit label counts (Types search, label chips) from this sure.
  static const double labelConfidence = 0.7;

  /// Recent searches kept: 2 lines of 4 on the Search tab (Aayush).
  static const int maxRecent = 8;

  /// Pictures in the "N images" preview (2 rows of 4).
  static const int previewCount = 8;

  /// Label chips on a result page (most common first).
  static const int maxLabelChips = 20;

  /// A month name needs at least this many letters ("oct").
  static const int minMonthLetters = 3;
}

/// One picture or video as Search knows it (SearchChannel's listing).
typedef SearchMedia = ({
  String id,
  String name,
  String album,
  int takenMs,
  bool video,
  int width,
  int height,
  int durationMs,
});

/// A named set of pictures from Intelligent classification (a named person,
/// a place, a neighbourhood, a type).
typedef SearchSet = ({String key, String title, List<String> ids});

/// What a search answer is.
enum SearchKind { person, place, type, album, text, fileName, date }

/// One search answer: a set of pictures the user can open.
final class SearchGroup {
  const SearchGroup({
    required this.kind,
    required this.key,
    required this.title,
    required this.ids,
  });

  final SearchKind kind;

  /// What opens it (a person id, a place name, "label:Smile"…; unique).
  final String key;

  /// Shown name (for text / file names / dates: the query or the date).
  final String title;

  /// Newest first.
  final List<String> ids;
}

/// Everything Search looks through, built once per library / scan change.
final class SearchIndex {
  SearchIndex({
    required List<SearchMedia> media,
    this.people = const [],
    this.places = const [],
    this.areas = const [],
    this.types = const [],
    Map<String, String> labels = const {},
    this.words = const {},
  }) : media = [...media]..sort((a, b) => b.takenMs.compareTo(a.takenMs)) {
    for (var i = 0; i < this.media.length; i++) {
      final m = this.media[i];
      _order[m.id] = i;
      byId[m.id] = m;
      (_albums[m.album] ??= []).add(m.id);
    }
    for (final entry in labels.entries) {
      if (!_order.containsKey(entry.key)) continue;
      final sure = sureLabels(entry.value);
      if (sure.isEmpty) continue;
      labelsOf[entry.key] = sure;
      for (final label in sure) {
        (_byLabel[label] ??= []).add(entry.key);
      }
    }
  }

  /// Newest first.
  final List<SearchMedia> media;
  final Map<String, SearchMedia> byId = {};

  /// Sure labels of each picture (see [SearchRules.labelConfidence]).
  final Map<String, Set<String>> labelsOf = {};

  /// Named people, towns, neighbourhoods, types (see [SearchSet]).
  final List<SearchSet> people;
  final List<SearchSet> places;
  final List<SearchSet> areas;
  final List<SearchSet> types;

  /// Text read in each picture (lower case).
  final Map<String, String> words;
  final Map<String, int> _order = {};
  final Map<String, List<String>> _albums = {};
  final Map<String, List<String>> _byLabel = {};

  /// [ids] that still exist, newest first, once each.
  List<String> ordered(Iterable<String> ids) {
    final known = {
      for (final id in ids)
        if (_order.containsKey(id)) id,
    }.toList();
    known.sort((a, b) => _order[a]!.compareTo(_order[b]!));
    return known;
  }

  /// Every answer for [query], by kind (person, place, type, album, text,
  /// file name, date); in a kind, most pictures first. Empty query = none.
  List<SearchGroup> search(String query) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return const [];
    final out = <SearchGroup>[];

    void addSets(
      SearchKind kind,
      Iterable<SearchSet> sets, {
      bool wordStart = false,
    }) {
      final found = <SearchGroup>[
        for (final set in sets)
          if (wordStart
              ? startsAWord(set.title, q)
              : set.title.toLowerCase().contains(q))
            SearchGroup(
              kind: kind,
              key: set.key,
              title: set.title,
              ids: ordered(set.ids),
            ),
      ]..removeWhere((g) => g.ids.isEmpty);
      found.sort((a, b) => b.ids.length.compareTo(a.ids.length));
      out.addAll(found);
    }

    addSets(SearchKind.person, people);

    // Towns first, then neighbourhoods not already named as a town.
    final placeTitles = {for (final p in places) p.title.toLowerCase()};
    addSets(SearchKind.place, [
      ...places,
      for (final a in areas)
        if (!placeTitles.contains(a.title.toLowerCase())) a,
    ]);

    // Types, then the other labels (not already a type: "Food"). A label
    // matches from the start of a word only: "om" inside "Community" or
    // "Room" would bring hundreds of pictures nobody looked for.
    final typeTitles = {for (final t in types) t.title.toLowerCase()};
    addSets(SearchKind.type, [
      ...types,
      for (final entry in _byLabel.entries)
        if (!typeTitles.contains(entry.key.toLowerCase()))
          (key: labelKey(entry.key), title: entry.key, ids: entry.value),
    ], wordStart: true);

    addSets(SearchKind.album, [
      for (final entry in _albums.entries)
        if (entry.key.isNotEmpty)
          (key: 'album:${entry.key}', title: entry.key, ids: entry.value),
    ]);

    final withText = [
      for (final entry in words.entries)
        if (entry.value.contains(q)) entry.key,
    ];
    _addOne(out, SearchKind.text, 'text:$q', q, withText);

    final named = [
      for (final m in media)
        if (m.name.toLowerCase().contains(q)) m.id,
    ];
    _addOne(out, SearchKind.fileName, 'file:$q', q, named);

    final date = parseSearchDate(q);
    if (date != null) {
      _addOne(out, SearchKind.date, date.key, date.title, [
        for (final m in media)
          if (date.matches(DateTime.fromMillisecondsSinceEpoch(m.takenMs)))
            m.id,
      ]);
    }
    return out;
  }

  void _addOne(
    List<SearchGroup> out,
    SearchKind kind,
    String key,
    String title,
    List<String> ids,
  ) {
    final list = ordered(ids);
    if (list.isEmpty) return;
    out.add(SearchGroup(kind: kind, key: key, title: title, ids: list));
  }

  /// Every picture of all answers ("N images"), newest first.
  List<String> allOf(List<SearchGroup> groups) =>
      ordered([for (final g in groups) ...g.ids]);
}

/// A label's answer key.
String labelKey(String label) => 'label:$label';

/// Lower case, trimmed, one space between words.
String normalizeQuery(String query) =>
    query.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

/// "Smile:0.83,Shoe:0.55" → the sure labels.
Set<String> sureLabels(String stored) {
  final out = <String>{};
  for (final part in stored.split(',')) {
    final i = part.lastIndexOf(':');
    if (i <= 0) continue;
    final confidence = double.tryParse(part.substring(i + 1)) ?? 0;
    if (confidence >= SearchRules.labelConfidence) {
      out.add(part.substring(0, i));
    }
  }
  return out;
}

const List<String> _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// A date typed in the search bar: a year ("2023"), a month ("oct",
/// "October", every year) or both ("october 2023", "2023 oct").
typedef SearchDate = ({
  int? year,
  int? month,
  String title,
  String key,
  bool Function(DateTime) matches,
});

SearchDate? parseSearchDate(String query) {
  final words = normalizeQuery(query).split(' ');
  if (words.isEmpty || words.length > 2) return null;
  int? year;
  int? month;
  for (final word in words) {
    final asYear = int.tryParse(word);
    if (asYear != null && word.length == 4 && asYear >= 1900) {
      if (year != null) return null;
      year = asYear;
      continue;
    }
    if (word.length < SearchRules.minMonthLetters) return null;
    final index = _months.indexWhere((m) => m.startsWith(word));
    if (index < 0 || month != null) return null;
    month = index + 1;
  }
  if (year == null && month == null) return null;
  final monthName = month == null
      ? null
      : '${_months[month - 1][0].toUpperCase()}${_months[month - 1].substring(1)}';
  return (
    year: year,
    month: month,
    title: [?monthName, ?year?.toString()].join(' '),
    key: 'date:${year ?? ''}-${month ?? ''}',
    matches: (d) =>
        (year == null || d.year == year) && (month == null || d.month == month),
  );
}

/// A filter chip on a result page: a year or a label.
typedef SearchChip = ({bool year, String value});

/// The chips of a result: its years (newest first), then its most common
/// sure labels (at most [SearchRules.maxLabelChips]).
List<SearchChip> chipsFor(List<String> ids, SearchIndex index) {
  final years = <int>{};
  final counts = <String, int>{};
  for (final id in ids) {
    final m = index.byId[id];
    if (m == null) continue;
    years.add(DateTime.fromMillisecondsSinceEpoch(m.takenMs).year);
    for (final label in index.labelsOf[id] ?? const <String>{}) {
      counts[label] = (counts[label] ?? 0) + 1;
    }
  }
  final labels = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return [
    for (final y in years.toList()..sort((a, b) => b.compareTo(a)))
      (year: true, value: '$y'),
    for (final l in labels.take(SearchRules.maxLabelChips))
      (year: false, value: l),
  ];
}

/// The pictures left by the chosen chips: any chosen year (none = every
/// year) AND every chosen label.
List<String> filterByChips(
  List<String> ids,
  Set<SearchChip> chosen,
  SearchIndex index,
) {
  if (chosen.isEmpty) return ids;
  final years = {
    for (final c in chosen)
      if (c.year) int.parse(c.value),
  };
  final labels = {
    for (final c in chosen)
      if (!c.year) c.value,
  };
  return [
    for (final id in ids)
      if (index.byId[id] case final m?)
        if ((years.isEmpty ||
                years.contains(
                  DateTime.fromMillisecondsSinceEpoch(m.takenMs).year,
                )) &&
            (index.labelsOf[id] ?? const <String>{}).containsAll(labels))
          id,
  ];
}

/// Recent searches: [query] first, an exact repeat moved up, at most
/// [SearchRules.maxRecent] (the oldest drop off).
List<String> addRecentSearch(List<String> recent, String query) {
  final q = query.trim();
  if (q.isEmpty) return recent;
  return [
    q,
    ...recent.where((r) => r != q),
  ].take(SearchRules.maxRecent).toList();
}

/// Does a word of [title] start with [query] ("Fast food" ← "foo")?
bool startsAWord(String title, String query) {
  final t = title.toLowerCase();
  if (t.startsWith(query)) return true;
  for (var i = t.indexOf(query); i > 0; i = t.indexOf(query, i + 1)) {
    if (!RegExp('[a-z0-9]').hasMatch(t[i - 1])) return true;
  }
  return false;
}
