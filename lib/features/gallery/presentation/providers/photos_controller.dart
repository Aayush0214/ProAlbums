import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/result_extension.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_query_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_controller.g.dart';

@immutable
final class PhotosState {
  const PhotosState({
    required this.items,
    required this.totalCount,
    required this.isLoadingMore,
  });

  /// Every item loaded so far, ALWAYS newest first. (The Photos tab reverses
  /// it for display when the user picks "Newest at the bottom".)
  final List<MediaItem> items;

  /// Total size of the library (for the "2,660 items" label).
  final int totalCount;

  /// true while the remaining pages are still loading in the background.
  final bool isLoadingMore;
}

/// Newest first by the SAME date the screen shows (createdAt). MediaStore can
/// sort by a different date (added/modified) than the one we display (taken),
/// which made one day appear several times ("Aug 13, Aug 14, Aug 13").
int _compareNewestFirst(MediaItem a, MediaItem b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  if (byDate != 0) return byDate;
  // Same second: stable, repeatable order (longer id = bigger number).
  if (a.id.length != b.id.length) return b.id.length.compareTo(a.id.length);
  return b.id.compareTo(a.id);
}

List<MediaItem> _sortedNewestFirst(List<MediaItem> items) =>
    List<MediaItem>.of(items)..sort(_compareNewestFirst);

/// Merges two lists that are ALREADY sorted newest first (O(n), no re-sort of
/// the whole library for every page).
List<MediaItem> _mergeNewestFirst(List<MediaItem> a, List<MediaItem> b) {
  final merged = <MediaItem>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    merged.add(_compareNewestFirst(a[i], b[j]) <= 0 ? a[i++] : b[j++]);
  }
  while (i < a.length) {
    merged.add(a[i++]);
  }
  while (j < b.length) {
    merged.add(b[j++]);
  }
  return merged;
}

/// Loads the whole library's METADATA (ids, dates, sizes: small objects, not
/// pixels) page by page, so that:
///  - the first screen appears after ONE small page (fast start), and
///  - the rest loads quietly in the background, so total height, sticky
///    headers and the fast-scroll bar are exact.
/// Thumbnails (the expensive part) are always loaded lazily, per visible tile.
@Riverpod(keepAlive: true)
class PhotosController extends _$PhotosController {
  static const int _pageSize = 300;
  static const Duration _refreshDelay = Duration(milliseconds: 600);

  // Every (re)load gets a number. A running background load that sees a newer
  // number knows it is outdated and stops. (Prevents old and new data mixing.)
  int _generation = 0;
  Timer? _refreshTimer;

  // Only ONE refresh runs at a time. A change that arrives meanwhile just sets
  // the flag, and the refresh runs once more when the current one is done.
  bool _refreshing = false;
  bool _refreshAgain = false;

  @override
  Future<PhotosState> build() async {
    final query = ref.watch(photosQueryControllerProvider);
    final generation = ++_generation;
    _refreshTimer?.cancel();

    // Photos added/removed outside the app (camera, WhatsApp...) -> refresh.
    ref
      ..listen(mediaLibraryChangesProvider, (previous, next) => _scheduleRefresh())
      ..onDispose(() => _refreshTimer?.cancel());

    final total = await _count(query);
    final firstPage = await _page(query, 0);
    final firstItems = _sortedNewestFirst(firstPage.items);

    if (firstPage.hasMore) {
      // Start AFTER build() has returned the first state.
      scheduleMicrotask(
        () => unawaited(_loadRemaining(generation, query, firstItems)),
      );
    }

    return PhotosState(
      items: firstItems,
      totalCount: total,
      isLoadingMore: firstPage.hasMore,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<int> _count(PhotosQuery query) async =>
      (await ref.read(getMediaCountUseCaseProvider)(query.kind)).valueOrThrow();

  Future<MediaPage> _page(PhotosQuery query, int page) async {
    final result = await ref.read(getMediaPageUseCaseProvider)(
      MediaPageRequest(page: page, pageSize: _pageSize, kind: query.kind),
    );
    return result.valueOrThrow();
  }

  /// Initial load: show the list GROWING (items appear as pages arrive).
  Future<void> _loadRemaining(
    int generation,
    PhotosQuery query,
    List<MediaItem> firstItems,
  ) async {
    var items = List<MediaItem>.of(firstItems);
    var page = 1;

    while (true) {
      final MediaPage loaded;
      try {
        loaded = await _page(query, page);
      } on Object catch (error, stackTrace) {
        // Keep what we already have, just stop loading more.
        AppLogger.e('Background load stopped', error: error, stackTrace: stackTrace);
        _publish(generation, items, isLoadingMore: false);
        return;
      }
      if (!_isCurrent(generation)) return;

      items = _mergeNewestFirst(items, _sortedNewestFirst(loaded.items));
      _publish(generation, items, isLoadingMore: loaded.hasMore);
      if (!loaded.hasMore) return;
      page++;
    }
  }

  void _publish(
    int generation,
    List<MediaItem> items, {
    required bool isLoadingMore,
  }) {
    if (!_isCurrent(generation)) return;
    final previousTotal = state.value?.totalCount ?? items.length;
    // A NEW list object each time, otherwise listeners would not see a change.
    state = AsyncData(
      PhotosState(
        items: List<MediaItem>.of(items),
        totalCount: previousTotal,
        isLoadingMore: isLoadingMore,
      ),
    );
  }

  void _scheduleRefresh() {
    AppLogger.d('[photos] library change event');
    // If a timer is already waiting, DO NOT restart it. Restarting ("debounce")
    // means a phone that keeps touching MediaStore (system gallery indexing)
    // would postpone the refresh again and again. This way the refresh always
    // starts at most [_refreshDelay] after the FIRST event.
    if (_refreshTimer?.isActive ?? false) return;
    _refreshTimer = Timer(_refreshDelay, () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        await _refreshOnce();
      } while (_refreshAgain && ref.mounted);
    } finally {
      _refreshing = false;
    }
  }

  /// Reload after a library change, WITHOUT shrinking the list on screen.
  ///
  /// Fast path (the normal case: you took a photo): read only the newest page
  /// and put the new items in front. One page request, shows up in ~1 second.
  /// Slow path (a photo was deleted or the numbers do not add up): reload
  /// everything and swap it in at once.
  Future<void> _refreshOnce() async {
    if (!ref.mounted) return;
    final query = ref.read(photosQueryControllerProvider);
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    AppLogger.d('[photos] refresh start');

    try {
      final total = await _count(query);
      final current = state.value;

      if (current != null && current.items.isNotEmpty) {
        final newest = await _page(query, 0);
        if (!_isCurrent(generation)) return;

        final known = <String>{for (final item in current.items) item.id};
        final added =
            newest.items.where((item) => !known.contains(item.id)).toList();
        final newestKnown = current.items.first.createdAt;
        final allAreNewer =
            added.every((item) => !item.createdAt.isBefore(newestKnown));

        if (added.isEmpty && total == current.items.length) {
          AppLogger.d('[photos] refresh: nothing new (${stopwatch.elapsedMilliseconds} ms)');
          return;
        }
        if (added.isNotEmpty &&
            allAreNewer &&
            current.items.length + added.length == total) {
          state = AsyncData(
            PhotosState(
              items: _mergeNewestFirst(
                _sortedNewestFirst(added),
                current.items,
              ),
              totalCount: total,
              isLoadingMore: false,
            ),
          );
          AppLogger.d(
            '[photos] refresh: +${added.length} new via fast path '
            '(${stopwatch.elapsedMilliseconds} ms)',
          );
          return;
        }
      }

      // Slow path.
      final items = <MediaItem>[];
      var page = 0;
      while (true) {
        final loaded = await _page(query, page);
        if (!_isCurrent(generation)) return;
        items.addAll(loaded.items);
        if (!loaded.hasMore) break;
        page++;
      }
      state = AsyncData(
        PhotosState(
          items: _sortedNewestFirst(items),
          totalCount: total,
          isLoadingMore: false,
        ),
      );
      AppLogger.d(
        '[photos] refresh: full reload, ${items.length} items '
        '(${stopwatch.elapsedMilliseconds} ms)',
      );
    } on Object catch (error, stackTrace) {
      // Old data stays on screen, which is better than an error screen.
      AppLogger.e('Library refresh failed', error: error, stackTrace: stackTrace);
    }
  }
}
