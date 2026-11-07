import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/data/thing_repository.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'thing_providers.g.dart';

@Riverpod(keepAlive: true)
LabelScanner labelScanner(Ref ref) => const MethodChannelLabelScanner();

@Riverpod(keepAlive: true)
ThingStore thingStore(Ref ref) => ThingStore(ref.watch(appDatabaseProvider));

/// Where the things scan is.
@immutable
final class ThingScanState {
  const ThingScanState({this.ready = false, this.version = 0});

  /// A scan has finished at least once.
  final bool ready;

  /// Goes up whenever the labels changed (pages reload).
  final int version;
}

/// The things' scan: ML Kit labels each picture once (again only when the
/// file changed), newest first, in batches so the albums fill while it
/// runs. Runs again (quietly) when the library changes. Started with the
/// other scans a few seconds after the app opens.
@Riverpod(keepAlive: true)
class ThingScan extends _$ThingScan {
  bool _running = false;
  bool _again = false;
  bool _started = false;
  Timer? _changed;

  static const int _batch = 48;

  @override
  ThingScanState build() {
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
    return const ThingScanState();
  }

  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(scan());
  }

  Future<void> scan() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        if (!await ref.read(classificationEnabledProvider.future)) return;
        await _scanOnce();
      } while (_again && ref.mounted);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Thing scan failed', error: error, stackTrace: stackTrace);
      if (ref.mounted) {
        state = ThingScanState(ready: true, version: state.version);
      }
    } finally {
      _running = false;
    }
  }

  void _bump({bool ready = false}) => state = ThingScanState(
    ready: ready || state.ready,
    version: state.version + 1,
  );

  /// Something the user did changed the albums ("Remove this type").
  void changed() => _bump();

  static const String _scanVersionKey = 'thing_scan_version';

  /// New way of reading pictures ([ThingRules.scanVersion]): every picture
  /// is looked at again.
  Future<void> _rescanIfReadingChanged(ThingStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_scanVersionKey) == ThingRules.scanVersion) return;
      await store.resetAll();
      await prefs.setInt(_scanVersionKey, ThingRules.scanVersion);
      AppLogger.d('Thing scan: pictures are read differently, scanning again');
    } on Object catch (error, stackTrace) {
      AppLogger.e('Thing rescan failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _scanOnce() async {
    final scanner = ref.read(labelScannerProvider);
    final store = ref.read(thingStoreProvider);
    final watch = Stopwatch()..start();
    await _rescanIfReadingChanged(store);

    final listed = await scanner.listImages();
    final read = await store.read();
    if (!ref.mounted) return;
    final byId = {for (final image in listed) image.id: image};
    final stale = [
      for (final entry in read.entries)
        if (byId[entry.key]?.modified != entry.value) entry.key,
    ];
    await store.forget(stale);
    final staleSet = stale.toSet();
    final todo = [
      for (final image in listed)
        if (!read.containsKey(image.id) || staleSet.contains(image.id))
          image.id,
    ];
    for (var i = 0, batches = 0; i < todo.length; i += _batch, batches++) {
      if (!ref.mounted ||
          !await ref.read(classificationEnabledProvider.future)) {
        return;
      }
      final ids = todo.sublist(i, (i + _batch).clamp(0, todo.length));
      await store.save(ids, await scanner.labels(ids), byId);
      // The albums fill while the scan runs.
      if ((batches + 1) % 10 == 0) _bump();
    }
    if (!ref.mounted) return;
    _bump(ready: true);

    final albums = await store.albums();
    AppLogger.d(
      'Thing scan: ${todo.length} new pictures in ${watch.elapsed.inSeconds}s; '
      '${[for (final kind in ThingKind.values) '${kind.title} ${albums[kind]?.length ?? 0}'].join(', ')}',
    );
    await _logTextGrid(store);
  }

  /// While tuning Documents: how many possible documents (not screenshots,
  /// not front camera, no people) have at least N characters (rows) over at
  /// least A of the picture (columns).
  Future<void> _logTextGrid(ThingStore store) async {
    final faces = await store.faceStats();
    final pictures = [
      for (final p in await store.labeled())
        if (!p.text.screenshot &&
            p.camera != 'front' &&
            (faces[p.id]?.biggest ?? 0) < ThingRules.bigFaceSize &&
            (faces[p.id]?.clear ?? 0) < 2)
          p.text,
    ];
    const charsSteps = [20, 40, 80, 120, 200];
    const areaSteps = [0.0, 0.02, 0.05, 0.08, 0.12];
    final rows = [
      for (final c in charsSteps)
        '≥$c: ${[for (final a in areaSteps) pictures.where((t) => t.chars >= c && t.area >= a).length].join('/')}',
    ];
    AppLogger.d(
      'Thing text grid (area ≥ ${areaSteps.join('/')}): ${rows.join('; ')}',
    );
  }
}

/// Every thing album (non-empty only). Reloads when labels or faces change.
@riverpod
Future<Map<ThingKind, List<ThingPicture>>> thingAlbumList(Ref ref) {
  ref
    ..watch(thingScanProvider.select((s) => s.version))
    ..watch(faceScanProvider.select((s) => s.version));
  return ref.read(thingStoreProvider).albums();
}

/// The pictures of a thing (Documents' "Blackboard writing" chip:
/// [blackboardOnly]), newest first.
@riverpod
List<MediaItem> thingItems(
  Ref ref,
  ThingKind kind, {
  bool blackboardOnly = false,
}) {
  final pictures =
      ref.watch(thingAlbumListProvider).value?[kind] ?? const <ThingPicture>[];
  return [
    for (final p in pictures)
      if (!blackboardOnly || p.blackboard)
        MediaItem(
          id: p.id,
          type: MediaType.image,
          createdAt: DateTime.fromMillisecondsSinceEpoch(p.takenMs),
          width: 0,
          height: 0,
        ),
  ];
}

/// A thing's grid: 4 columns, no date headers.
const int thingGridColumns = 4;

@riverpod
List<GalleryRow> thingRows(
  Ref ref,
  ThingKind kind, {
  bool blackboardOnly = false,
}) => GalleryRowsBuilder.buildFlat(
  items: ref.watch(thingItemsProvider(kind, blackboardOnly: blackboardOnly)),
  columns: thingGridColumns,
  alignToEnd: false,
);

/// Fewer characters than this is no text worth the viewer's [T] button
/// (a stray letter in a pattern).
const int _minViewerTextChars = 4;

/// The viewer's [T] button: the scan read text in this picture (only with
/// Intelligent classification on).
@riverpod
Future<bool> photoHasText(Ref ref, String mediaId) async {
  if (!await ref.watch(classificationEnabledProvider.future)) return false;
  ref.watch(thingScanProvider.select((s) => s.version));
  final chars = await ref.read(thingStoreProvider).textCharsOf(mediaId);
  return chars >= _minViewerTextChars;
}

/// The text lines of a picture (each 0–1 of the upright picture), read
/// when the viewer's [T] is turned on.
@riverpod
Future<List<Rect>> photoTextLines(Ref ref, String mediaId) async => [
  for (final l in await ref.read(labelScannerProvider).textLines(mediaId))
    Rect.fromLTRB(l[0], l[1], l[2], l[3]),
];
