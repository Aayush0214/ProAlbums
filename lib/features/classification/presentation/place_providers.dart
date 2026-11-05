import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/classification/data/place_repository.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'place_providers.g.dart';

@Riverpod(keepAlive: true)
PlaceScanner placeScanner(Ref ref) => const MethodChannelPlaceScanner();

@Riverpod(keepAlive: true)
PlaceStore placeStore(Ref ref) => PlaceStore(ref.watch(appDatabaseProvider));

/// Where the Location scan is.
@immutable
final class PlaceScanState {
  const PlaceScanState({
    this.ready = false,
    this.allowed = true,
    this.version = 0,
  });

  /// A scan has finished at least once.
  final bool ready;

  /// The app may read where pictures were taken.
  final bool allowed;

  /// Goes up whenever the places changed (pages reload).
  final int version;

  PlaceScanState copyWith({bool? ready, bool? allowed, int? version}) =>
      PlaceScanState(
        ready: ready ?? this.ready,
        allowed: allowed ?? this.allowed,
        version: version ?? this.version,
      );
}

/// Location's scan: reads each picture's GPS place once (again only when
/// the file changed), then names each small square of the map once with
/// Android's Geocoder (needs the internet; unnamed squares are asked again
/// a day later). Runs again (quietly) when the library changes. Started
/// with People's scan, a few seconds after the app opens.
@Riverpod(keepAlive: true)
class PlaceScan extends _$PlaceScan {
  bool _running = false;
  bool _again = false;
  bool _started = false;
  Timer? _changed;

  static const int _batch = 48;

  @override
  PlaceScanState build() {
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
    return const PlaceScanState();
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
      AppLogger.e('Place scan failed', error: error, stackTrace: stackTrace);
      if (ref.mounted) state = state.copyWith(ready: true);
    } finally {
      _running = false;
    }
  }

  void _bump() => state = state.copyWith(version: state.version + 1);

  Future<void> _scanOnce() async {
    final scanner = ref.read(placeScannerProvider);
    final store = ref.read(placeStoreProvider);
    final watch = Stopwatch()..start();

    final allowed = await scanner.permission();
    if (!ref.mounted) return;
    if (!allowed) {
      state = state.copyWith(ready: true, allowed: false);
      return;
    }
    state = state.copyWith(allowed: true);

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
    for (var i = 0; i < todo.length; i += _batch) {
      if (!ref.mounted) return;
      final ids = todo.sublist(i, (i + _batch).clamp(0, todo.length));
      await store.save(ids, await scanner.locations(ids), byId);
    }
    if (stale.isNotEmpty || todo.isNotEmpty) _bump();

    // Names, one square at a time.
    final cells = (await store.cellsToName(DateTime.now()))
        .take(PlaceRules.maxNamesPerScan)
        .toList();
    var named = 0;
    for (final cell in cells) {
      if (!ref.mounted) return;
      final center = placeCellCenter(cell);
      final address = await scanner.address(center.lat, center.lng);
      final name = address == null ? null : placeNameFrom(address);
      await store.saveName(
        cell,
        name: name,
        label: address == null ? null : placeLabelFrom(address),
        now: DateTime.now(),
      );
      if (name != null && ++named % 20 == 0) _bump();
    }
    if (!ref.mounted) return;
    if (named > 0) _bump();
    state = state.copyWith(ready: true);

    final counts = await store.counts();
    final albums = await store.albums();
    AppLogger.d(
      'Place scan: ${todo.length} new pictures, ${cells.length} squares '
      'asked ($named named) in ${watch.elapsed.inSeconds}s; total '
      '${counts.pictures} pictures, ${counts.placed} with a place, '
      '${counts.cells} squares (${counts.named} named), '
      '${albums.length} places: '
      '${albums.map((a) => '${a.name} ${a.pictures.length}').join(', ')}',
    );
  }
}

/// The place albums, most pictures first.
@riverpod
Future<List<PlaceAlbum>> placeAlbumList(Ref ref) {
  ref.watch(placeScanProvider.select((s) => s.version));
  return ref.read(placeStoreProvider).albums();
}

MediaItem _itemOf(PlacedPicture p) => MediaItem(
  id: p.id,
  type: MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(p.takenMs),
  width: 0,
  height: 0,
);

/// The pictures of one place, newest first.
@riverpod
List<MediaItem> placeItems(Ref ref, String name) {
  final albums = ref.watch(placeAlbumListProvider).value ?? const [];
  for (final album in albums) {
    if (album.name == name) return [for (final p in album.pictures) _itemOf(p)];
  }
  return const [];
}

/// A place's grid: 4 columns, no date headers.
const int placeGridColumns = 4;

@riverpod
List<GalleryRow> placeRows(Ref ref, String name) =>
    GalleryRowsBuilder.buildFlat(
      items: ref.watch(placeItemsProvider(name)),
      columns: placeGridColumns,
      alignToEnd: false,
    );

/// The viewer's place line of a picture ("Khilachipur-Ujjain Division"),
/// null = none (no place, not named yet, or Intelligent classification is
/// off).
@riverpod
Future<String?> photoPlaceLabel(Ref ref, String mediaId) async {
  ref.watch(placeScanProvider.select((s) => s.version));
  if (!await ref.watch(classificationEnabledProvider.future)) return null;
  return ref.read(placeStoreProvider).labelOf(mediaId);
}
