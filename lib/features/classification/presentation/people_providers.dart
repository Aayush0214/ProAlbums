import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'people_providers.g.dart';

/// Every person with their picture count and cover (reloads when the scan
/// or the user changes the people).
@riverpod
Future<List<PersonSummary>> allPeople(Ref ref) {
  ref.watch(faceScanProvider.select((s) => s.version));
  return ref.read(faceStoreProvider).people();
}

PersonStanding _standing(PersonSummary p) =>
    (id: p.id, shown: p.shown, pictures: p.pictures, changedAt: p.changedAt);

/// The People page, in its order (see [peopleOnPage]).
@riverpod
List<PersonSummary> peopleShown(Ref ref) {
  final all = ref.watch(allPeopleProvider).value ?? const [];
  final byId = {for (final p in all) p.id: p};
  return [
    for (final id in peopleOnPage(all.map(_standing).toList())) byId[id]!,
  ];
}

/// The "+" page: everyone else seen in a few pictures, most first (hidden
/// people come back from here).
@riverpod
List<PersonSummary> peopleToAdd(Ref ref) {
  final all = ref.watch(allPeopleProvider).value ?? const [];
  final shown = {for (final p in ref.watch(peopleShownProvider)) p.id};
  return [
    for (final p in all)
      if (!shown.contains(p.id) && p.pictures >= FaceRules.minPicturesToAdd) p,
  ]..sort((a, b) => b.pictures.compareTo(a.pictures));
}

/// One person (null = gone, e.g. merged away).
@riverpod
PersonSummary? person(Ref ref, int personId) {
  for (final p
      in ref.watch(allPeopleProvider).value ?? const <PersonSummary>[]) {
    if (p.id == personId) return p;
  }
  return null;
}

/// A person's faces, newest picture first.
@riverpod
Future<List<StoredFace>> personFaces(Ref ref, int personId) {
  ref.watch(faceScanProvider.select((s) => s.version));
  return ref.read(faceStoreProvider).facesOf(personId);
}

MediaItem _itemOf(String id, int takenMs) => MediaItem(
  id: id,
  type: MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(takenMs),
  width: 0,
  height: 0,
);

/// Every picture of a person, newest first ("Show all", the viewer).
@riverpod
List<MediaItem> personItems(Ref ref, int personId) {
  final faces = ref.watch(personFacesProvider(personId)).value ?? const [];
  final seen = <String>{};
  return [
    for (final face in faces)
      if (seen.add(face.mediaId)) _itemOf(face.mediaId, face.takenMs),
  ];
}

/// The featured pictures (see [featuredPictures]), newest first.
@riverpod
List<MediaItem> personFeatured(Ref ref, int personId) {
  final faces = ref.watch(personFacesProvider(personId)).value ?? const [];
  final taken = {for (final f in faces) f.mediaId: f.takenMs};
  return [
    for (final id in featuredPictures([
      for (final f in faces)
        (mediaId: f.mediaId, quality: f.quality, takenMs: f.takenMs),
    ]))
      _itemOf(id, taken[id] ?? 0),
  ];
}

/// Featured pictures: 2 big columns; "Show all": 4 columns. Fixed (no
/// pinch), like the system gallery.
int personGridColumns({required bool showAll}) => showAll ? 4 : 2;

@riverpod
List<GalleryRow> personRows(Ref ref, int personId, {required bool showAll}) =>
    GalleryRowsBuilder.buildFlat(
      items: ref.watch(
        showAll
            ? personItemsProvider(personId)
            : personFeaturedProvider(personId),
      ),
      columns: personGridColumns(showAll: showAll),
      alignToEnd: false,
    );

const String _dismissedKey = 'people_similar_dismissed';

/// Pairs closed with ✕ on "Similar people have been detected" ('a-b',
/// smaller id first): not offered again.
@Riverpod(keepAlive: true)
class DismissedSimilar extends _$DismissedSimilar {
  @override
  Future<Set<String>> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_dismissedKey) ?? const []).toSet();
    } on Object {
      return const {};
    }
  }

  static String pair(int a, int b) => a < b ? '$a-$b' : '$b-$a';

  Future<void> dismiss(int a, int b) async {
    final next = {...state.value ?? const <String>{}, pair(a, b)};
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedKey, next.toList());
    } on Object {
      // Offered again next time.
    }
  }
}

/// The person most like [personId] that could be the same one (null =
/// none, or closed with ✕).
@riverpod
Future<PersonSummary?> similarPerson(Ref ref, int personId) async {
  ref.watch(faceScanProvider.select((s) => s.version));
  final dismissed = await ref.watch(dismissedSimilarProvider.future);
  final people = await ref.watch(allPeopleProvider.future);
  final means = await ref.read(faceStoreProvider).means();
  final me = means.where((m) => m.id == personId).firstOrNull;
  if (me == null) return null;
  final byId = {for (final p in people) p.id: p};
  for (final id in similarPeople(me, means)) {
    final other = byId[id];
    if (other == null || other.pictures < FaceRules.minPicturesToAdd) continue;
    if (dismissed.contains(DismissedSimilar.pair(personId, id))) continue;
    return other;
  }
  return null;
}
