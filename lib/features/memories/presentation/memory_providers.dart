import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/search/presentation/search_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_providers.g.dart';

@Riverpod(keepAlive: true)
MemoryStore memoryStore(Ref ref) => MemoryStore(ref.watch(appDatabaseProvider));

/// A Featured picture.
typedef FeaturedPicture = ({String id, int takenMs});

/// Where the memories are.
@immutable
final class MemoryScanState {
  const MemoryScanState({
    this.ready = false,
    this.version = 0,
    this.featured = const [],
  });

  /// Made at least once.
  final bool ready;

  /// Goes up whenever the memories changed (pages reload).
  final int version;

  /// Featured pictures, newest first.
  final List<FeaturedPicture> featured;
}

/// Makes the memories and Featured from the pictures (see MemoryRules):
/// times from the whole library; people, towns and group photos from
/// Intelligent classification when it is on. Runs a few seconds after the
/// app opens and again (quietly) when the library or a scan has news. The
/// rules run in an isolate; the result is saved (MemoryStore.sync keeps
/// what the user changed).
@Riverpod(keepAlive: true)
class MemoryScan extends _$MemoryScan {
  bool _running = false;
  bool _again = false;
  bool _started = false;
  Timer? _later;

  static const Duration _settle = Duration(seconds: 3);

  @override
  MemoryScanState build() {
    void soon() {
      if (!_started) return;
      _later?.cancel();
      _later = Timer(_settle, () => unawaited(run()));
    }

    ref
      ..listen(mediaLibraryChangesProvider, (_, _) => soon())
      ..listen(faceScanProvider.select((s) => s.version), (_, _) => soon())
      ..listen(placeScanProvider.select((s) => s.version), (_, _) => soon())
      ..listen(thingScanProvider.select((s) => s.version), (_, _) => soon())
      ..listen(classificationEnabledProvider, (_, _) => soon())
      ..onDispose(() => _later?.cancel());
    return const MemoryScanState();
  }

  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(run());
  }

  /// Something the user did changed the memories (rename, delete…).
  void changed() => state = MemoryScanState(
    ready: state.ready,
    version: state.version + 1,
    featured: state.featured,
  );

  Future<void> run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _runOnce();
      } while (_again && ref.mounted);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Memory scan failed', error: error, stackTrace: stackTrace);
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnce() async {
    final watch = Stopwatch()..start();
    final library = await ref.read(libraryMediaProvider.future);
    final media = library.media;
    final classification = await ref.read(classificationEnabledProvider.future);
    if (!ref.mounted) return;

    final faces = <String, List<({double size, double sharpness})>>{};
    final peopleIn = <String, Set<int>>{};
    final placeOf = <String, String>{};
    var documents = const <String>{};
    var groupPhotos = const <String>{};
    final people = <MemoryPerson>[];
    if (classification) {
      for (final f in await ref.read(faceStoreProvider).allFaces()) {
        (faces[f.mediaId] ??= []).add((size: f.size, sharpness: f.sharpness));
        if (f.personId case final id?) (peopleIn[f.mediaId] ??= {}).add(id);
      }
      for (final p in await ref.read(placeStoreProvider).named()) {
        placeOf[p.id] = p.place;
      }
      final things = await ref.read(thingStoreProvider).albums();
      documents = {
        for (final p in things[ThingKind.documents] ?? const <ThingPicture>[])
          p.id,
      };
      groupPhotos = {
        for (final p in things[ThingKind.groupPhoto] ?? const <ThingPicture>[])
          p.id,
      };
      // The people of the People page (read from the store: the page's
      // providers are only alive while it is open), most pictures first:
      // the page puts recently changed (named) people first, memories
      // want the people seen most.
      final all = await ref.read(faceStoreProvider).people();
      final byId = {for (final p in all) p.id: p};
      final onPage = peopleOnPage([
        for (final p in all)
          (
            id: p.id,
            shown: p.shown,
            pictures: p.pictures,
            changedAt: p.changedAt,
          ),
      ])..sort((a, b) => byId[b]!.pictures.compareTo(byId[a]!.pictures));
      for (final id in onPage) {
        people.add((id: id, name: byId[id]!.name));
      }
    }

    final photos = <MemoryPhoto>[
      for (final m in media)
        if (!m.video &&
            // When it was taken is not known: it cannot be in a memory.
            !library.undated.contains(m.id) &&
            !m.album.toLowerCase().contains('screenshot') &&
            !documents.contains(m.id))
          (
            id: m.id,
            takenMs: m.takenMs,
            place: placeOf[m.id] ?? '',
            people: peopleIn[m.id] ?? const <int>{},
            quality: photoQuality(faces[m.id] ?? const []),
            biggestFace: [
              0.0,
              for (final f
                  in faces[m.id] ?? const <({double size, double sharpness})>[])
                f.size,
            ].reduce((a, b) => a > b ? a : b),
            groupPhoto: groupPhotos.contains(m.id),
          ),
    ];

    final made = await Isolate.run(
      () => _make((photos: photos, people: people)),
    );
    if (!ref.mounted) return;
    final store = ref.read(memoryStoreProvider);
    await store.sync(made.drafts, {for (final m in media) m.id});
    if (!ref.mounted) return;
    state = MemoryScanState(
      ready: true,
      version: state.version + 1,
      featured: made.featured,
    );

    final saved = await store.memories();
    AppLogger.d(
      'Memory scan: ${photos.length} pictures → ${made.drafts.length} '
      'memories (${saved.length} shown), ${made.featured.length} featured in '
      '${watch.elapsed.inMilliseconds} ms (people: ${people.length}, '
      'undated: ${library.undated.length})',
    );
    // One line each (a log line is cut after ~1000 characters).
    for (final m in saved) {
      AppLogger.d(
        '  memory: ${m.title} [${m.kind.name}, '
        '${m.shown.length}/${m.candidates}, ${_range(m.startMs, m.endMs)}]',
      );
    }
  }
}

String _range(int startMs, int endMs) {
  String day(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month}-${d.day}';
  }

  return '${day(startMs)}..${day(endMs)}';
}

/// Runs in an isolate (top level: nothing else is captured).
({List<MemoryDraft> drafts, List<FeaturedPicture> featured}) _make(
  ({List<MemoryPhoto> photos, List<MemoryPerson> people}) input,
) => (
  drafts: buildMemories(input.photos, people: input.people),
  featured: [
    for (final p in featuredPhotos(input.photos))
      (id: p.id, takenMs: p.takenMs),
  ],
);

/// The saved memories (reloads when they change).
@riverpod
Future<List<StoredMemory>> memoryList(Ref ref) {
  ref.watch(memoryScanProvider.select((s) => s.version));
  return ref.read(memoryStoreProvider).memories();
}

/// Starts the memories a few seconds after the app opens (after the
/// classification scans have started).
class MemoriesAutoStart extends ConsumerStatefulWidget {
  const MemoriesAutoStart({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MemoriesAutoStart> createState() => _MemoriesAutoStartState();
}

class _MemoriesAutoStartState extends ConsumerState<MemoriesAutoStart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) ref.read(memoryScanProvider.notifier).ensureStarted();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Featured pictures for the grid / viewer, newest first.
@riverpod
List<MediaItem> featuredItems(Ref ref) => [
  for (final f in ref.watch(memoryScanProvider.select((s) => s.featured)))
    MediaItem(
      id: f.id,
      type: MediaType.image,
      createdAt: DateTime.fromMillisecondsSinceEpoch(f.takenMs),
      width: 0,
      height: 0,
    ),
];
