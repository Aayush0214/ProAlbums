import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/search/data/search_repository.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_providers.g.dart';

@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) => const DeviceSearchRepository();

/// Everything Search looks through. Built again when the library changes
/// or a classification scan has news. With Intelligent classification off
/// only the library itself (albums, file names, dates) is searched.
@Riverpod(keepAlive: true)
Future<SearchIndex> searchIndex(Ref ref) async {
  ref
    ..watch(mediaLibraryChangesProvider)
    ..watch(faceScanProvider.select((s) => s.version))
    ..watch(placeScanProvider.select((s) => s.version))
    ..watch(thingScanProvider.select((s) => s.version));
  final media = await ref.read(searchRepositoryProvider).listMedia();
  final classification = await ref.watch(classificationEnabledProvider.future);
  if (!classification) return SearchIndex(media: media);

  final faces = ref.read(faceStoreProvider);
  final people = <SearchSet>[
    for (final person in await faces.people())
      if (person.name case final name? when name.trim().isNotEmpty)
        (
          key: '${person.id}',
          title: name,
          ids: [for (final f in await faces.facesOf(person.id)) f.mediaId],
        ),
  ];

  final placed = await ref.read(placeStoreProvider).named();
  final byPlace = <String, List<String>>{};
  final byArea = <String, List<String>>{};
  for (final p in placed) {
    (byPlace[p.place] ??= []).add(p.id);
    if (p.area.isNotEmpty) (byArea[p.area] ??= []).add(p.id);
  }

  final things = ref.read(thingStoreProvider);
  final albums = await things.albums();
  final seen = await things.searchable();

  return SearchIndex(
    media: media,
    people: people,
    places: [
      for (final e in byPlace.entries) (key: e.key, title: e.key, ids: e.value),
    ],
    areas: [
      for (final e in byArea.entries)
        (key: 'area:${e.key}', title: e.key, ids: e.value),
    ],
    types: [
      for (final kind in ThingKind.values)
        if (albums[kind] case final pictures? when pictures.isNotEmpty)
          (
            key: thingAlbumId(kind),
            title: kind.title,
            ids: [for (final p in pictures) p.id],
          ),
    ],
    labels: {for (final s in seen) s.id: s.labels},
    words: {
      for (final s in seen)
        if (s.words.isNotEmpty) s.id: s.words,
    },
  );
}

/// The answers for a query (empty query = none).
@riverpod
Future<List<SearchGroup>> searchResults(Ref ref, String query) async {
  final index = await ref.watch(searchIndexProvider.future);
  return index.search(query);
}

/// A Search picture as the shared grid / viewer knows it.
MediaItem searchMediaItem(SearchMedia m) => MediaItem(
  id: m.id,
  type: m.video ? MediaType.video : MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(m.takenMs),
  width: m.width,
  height: m.height,
  duration: Duration(milliseconds: m.durationMs),
);

/// Recent searches (newest first, kept on the phone).
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  @override
  Future<List<String>> build() async =>
      (await ref.read(searchRepositoryProvider).recentSearches())
          .take(SearchRules.maxRecent)
          .toList();

  Future<void> add(String query) async {
    final next = addRecentSearch(await future, query);
    state = AsyncData(next);
    await ref.read(searchRepositoryProvider).saveRecentSearches(next);
  }

  /// Long press > ✕ on one recent search.
  Future<void> remove(String query) async {
    final next = [...await future]..remove(query);
    state = AsyncData(next);
    await ref.read(searchRepositoryProvider).saveRecentSearches(next);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await ref.read(searchRepositoryProvider).saveRecentSearches(const []);
  }
}

/// What a Search result page shows.
enum SearchTargetKind {
  /// A person from the Search tab's People row (named or not).
  person,

  /// A town from the Location row.
  place,

  /// A type (Documents, Food…) from the Types row.
  thing,

  /// One answer of a query ([SearchTarget.key] = [SearchGroup.key]).
  answer,

  /// "N images · View all": every answer of a query.
  all,
}

/// What a Search result page shows, and its title.
@immutable
final class SearchTarget {
  const SearchTarget({
    required this.kind,
    required this.title,
    this.key = '',
    this.query = '',
  });

  final SearchTargetKind kind;
  final String title;

  /// Person id, place name, ThingKind name, or the answer's key.
  final String key;

  /// The search (answers / all).
  final String query;

  /// One scope / selection per page.
  String get scopeId => 'search:${kind.name}:$key:$query';

  @override
  bool operator ==(Object other) =>
      other is SearchTarget &&
      other.kind == kind &&
      other.key == key &&
      other.query == query &&
      other.title == title;

  @override
  int get hashCode => Object.hash(kind, key, query, title);
}

/// The pictures of a result page (before chips), newest first. Follows
/// the library and the scans (a deleted picture leaves).
@riverpod
Future<List<String>> searchTargetIds(Ref ref, SearchTarget target) async {
  final index = await ref.watch(searchIndexProvider.future);
  switch (target.kind) {
    case SearchTargetKind.person:
      final id = int.tryParse(target.key);
      if (id == null) return const [];
      final faces = await ref.watch(personFacesProvider(id).future);
      return index.ordered([for (final f in faces) f.mediaId]);
    case SearchTargetKind.place:
      return index.ordered([
        for (final item in ref.watch(placeItemsProvider(target.key))) item.id,
      ]);
    case SearchTargetKind.thing:
      final kind = ThingKind.values.where((k) => k.name == target.key);
      if (kind.isEmpty) return const [];
      final albums = await ref.watch(thingAlbumListProvider.future);
      return index.ordered([
        for (final p in albums[kind.first] ?? const <ThingPicture>[]) p.id,
      ]);
    case SearchTargetKind.answer:
      final groups = index.search(target.query);
      return groups.where((g) => g.key == target.key).firstOrNull?.ids ??
          const [];
    case SearchTargetKind.all:
      return index.allOf(index.search(target.query));
  }
}

/// A result page's chips (see [chipsFor]).
@riverpod
List<SearchChip> searchTargetChips(Ref ref, SearchTarget target) {
  final ids = ref.watch(searchTargetIdsProvider(target)).value;
  final index = ref.watch(searchIndexProvider).value;
  if (ids == null || index == null) return const [];
  return chipsFor(ids, index);
}

/// Chosen chips as one provider key ("y:2023|l:Smile", sorted).
String searchChipsKey(Set<SearchChip> chosen) => ([
  for (final c in chosen) '${c.year ? 'y' : 'l'}:${c.value}',
]..sort()).join('|');

Set<SearchChip> _chipsOfKey(String key) => {
  for (final part in key.split('|'))
    if (part.length > 2)
      (year: part.startsWith('y:'), value: part.substring(2)),
};

/// A result page's pictures after the chosen chips ([chips] =
/// [searchChipsKey]).
@riverpod
List<MediaItem> searchTargetItems(
  Ref ref,
  SearchTarget target, {
  String chips = '',
}) {
  final ids = ref.watch(searchTargetIdsProvider(target)).value;
  final index = ref.watch(searchIndexProvider).value;
  if (ids == null || index == null) return const [];
  return [
    for (final id in filterByChips(ids, _chipsOfKey(chips), index))
      if (index.byId[id] case final m?) searchMediaItem(m),
  ];
}

/// A result page's grid: 4 columns, no date headers.
const int searchGridColumns = 4;

@riverpod
List<GalleryRow> searchTargetRows(
  Ref ref,
  SearchTarget target, {
  String chips = '',
}) => GalleryRowsBuilder.buildFlat(
  items: ref.watch(searchTargetItemsProvider(target, chips: chips)),
  columns: searchGridColumns,
  alignToEnd: false,
);
