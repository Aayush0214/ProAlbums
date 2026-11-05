import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'classification_providers.g.dart';

@Riverpod(keepAlive: true)
FaceScanner faceScanner(Ref ref) => const MethodChannelFaceScanner();

@Riverpod(keepAlive: true)
FaceStore faceStore(Ref ref) => FaceStore(ref.watch(appDatabaseProvider));

const String _enabledKey = 'intelligent_classification_enabled';

/// Settings > "Intelligent classification" (on by default). Off: nothing is
/// scanned and Albums hides the section (what was found is kept, so turning
/// it on shows it again at once).
@Riverpod(keepAlive: true)
class ClassificationEnabled extends _$ClassificationEnabled {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> save({required bool enabled}) async {
    state = AsyncData(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } on Object {
      // Back to the default next time.
    }
  }
}

/// Where the face scan is.
@immutable
final class FaceScanState {
  const FaceScanState({
    this.ready = false,
    this.scanning = false,
    this.done = 0,
    this.total = 0,
    this.version = 0,
  });

  /// A scan has finished at least once.
  final bool ready;
  final bool scanning;

  /// Pictures looked at / to look at in this scan.
  final int done;
  final int total;

  /// Goes up whenever the people changed (pages reload).
  final int version;

  FaceScanState copyWith({
    bool? ready,
    bool? scanning,
    int? done,
    int? total,
    int? version,
  }) => FaceScanState(
    ready: ready ?? this.ready,
    scanning: scanning ?? this.scanning,
    done: done ?? this.done,
    total: total ?? this.total,
    version: version ?? this.version,
  );
}

/// People's scan: each picture is looked at once (again only when the file
/// changed), newest first; faces are given to people every ~240 pictures,
/// so people appear while the scan goes on. Runs again (quietly) when the
/// library changes. Started a few seconds after the app opens.
@Riverpod(keepAlive: true)
class FaceScan extends _$FaceScan {
  bool _running = false;
  bool _again = false;
  bool _started = false;
  Timer? _changed;

  static const int _batch = 24;

  /// Group the found faces after this many batches.
  static const int _groupEvery = 10;

  @override
  FaceScanState build() {
    ref
      ..listen(mediaLibraryChangesProvider, (_, _) {
        if (!_started) return;
        _changed?.cancel();
        _changed = Timer(const Duration(seconds: 2), () => unawaited(scan()));
      })
      ..listen(classificationEnabledProvider, (_, next) {
        if ((next.value ?? false) && _started) unawaited(scan());
      })
      ..onDispose(() => _changed?.cancel());
    return const FaceScanState();
  }

  /// First call starts the scan; later calls do nothing.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(scan());
  }

  /// Something the user did changed the people (merge, name, …).
  void peopleChanged() => state = state.copyWith(version: state.version + 1);

  Future<bool> _enabled() => ref.read(classificationEnabledProvider.future);

  Future<void> scan() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        if (!await _enabled()) {
          state = state.copyWith(scanning: false);
          return;
        }
        await _scanOnce();
      } while (_again && ref.mounted);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Face scan failed', error: error, stackTrace: stackTrace);
      if (ref.mounted) state = state.copyWith(scanning: false, ready: true);
    } finally {
      _running = false;
    }
  }

  static const String _groupingVersionKey = 'face_grouping_version';

  /// New grouping rules ([FaceRules.groupingVersion]): group every face
  /// again (no picture is looked at again).
  Future<void> _regroupIfRulesChanged(FaceStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_groupingVersionKey) == FaceRules.groupingVersion) {
        return;
      }
      await store.resetGrouping();
      await prefs.setInt(_groupingVersionKey, FaceRules.groupingVersion);
      AppLogger.d('Face scan: grouping rules changed, grouping again');
    } on Object catch (error, stackTrace) {
      AppLogger.e('Face regroup failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _scanOnce() async {
    final scanner = ref.read(faceScannerProvider);
    final store = ref.read(faceStoreProvider);
    final watch = Stopwatch()..start();
    await _regroupIfRulesChanged(store);
    final listed = await scanner.listImages();
    final scanned = await store.scanned();
    if (!ref.mounted) return;

    final byId = {for (final image in listed) image.id: image};
    // Gone, or changed since it was looked at: forget (changed ones are
    // looked at again below).
    final stale = [
      for (final entry in scanned.entries)
        if (byId[entry.key]?.modified != entry.value) entry.key,
    ];
    await store.forget(stale);
    final staleSet = stale.toSet();
    final todo = [
      for (final image in listed)
        if (!scanned.containsKey(image.id) || staleSet.contains(image.id))
          image.id,
    ];
    var changed = stale.isNotEmpty;
    state = state.copyWith(
      scanning: todo.isNotEmpty,
      done: 0,
      total: todo.length,
    );

    for (var i = 0, batches = 0; i < todo.length; i += _batch, batches++) {
      if (!await _enabled() || !ref.mounted) break;
      final ids = todo.sublist(i, (i + _batch).clamp(0, todo.length));
      final found = await scanner.analyze(ids);
      // Pictures that could not be read are remembered as "no faces" so
      // they are not tried again every time (until the file changes).
      final answered = {for (final image in found) image.id};
      await store.saveAnalyzed([
        ...found,
        for (final id in ids)
          if (!answered.contains(id)) (id: id, faces: const <FoundFace>[]),
      ], byId);
      if (!ref.mounted) return;
      state = state.copyWith(done: i + ids.length);
      if ((batches + 1) % _groupEvery == 0 && await store.groupNewFaces()) {
        changed = true;
        if (!ref.mounted) return;
        state = state.copyWith(version: state.version + 1);
      }
    }

    if (await store.groupNewFaces()) changed = true;
    if (!ref.mounted) return;
    state = state.copyWith(
      ready: true,
      scanning: false,
      version: changed ? state.version + 1 : state.version,
    );
    final counts = await store.counts();
    final people = await store.people();
    final onPage = peopleOnPage([
      for (final p in people)
        (
          id: p.id,
          shown: p.shown,
          pictures: p.pictures,
          changedAt: p.changedAt,
        ),
    ]);
    final biggest = [...people]
      ..sort((a, b) => b.pictures.compareTo(a.pictures));
    final top = <String>[];
    for (final p in biggest.take(8)) {
      final c = await store.cohesion(p.id);
      top.add(
        '${p.pictures} (avg ${c.average.toStringAsFixed(2)}, '
        'strays ${(c.strays * 100).round()}%)',
      );
    }
    AppLogger.d(
      'Face scan: ${todo.length} new pictures in '
      '${watch.elapsed.inSeconds}s; total ${counts.pictures} pictures, '
      '${counts.faces} faces, ${counts.people} people, '
      '${onPage.length} on the People page; top people: ${top.join('; ')}; '
      'next: ${biggest.skip(8).take(17).map((p) => p.pictures).join(', ')}',
    );
  }
}
