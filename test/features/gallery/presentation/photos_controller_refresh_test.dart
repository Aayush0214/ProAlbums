import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';

MediaItem _item(String id, DateTime createdAt) => MediaItem(
      id: id,
      type: MediaType.image,
      createdAt: createdAt,
      width: 100,
      height: 100,
    );

/// A gallery you can change while the test runs (like taking a photo).
class MutableFakeRepository implements MediaRepository {
  MutableFakeRepository(this.library);

  /// Newest first.
  List<MediaItem> library;
  final StreamController<Result<Unit>> changes =
      StreamController<Result<Unit>>.broadcast();
  int pageCalls = 0;

  void notifyChange() => changes.add(right<Failure, Unit>(unit));

  @override
  FutureResult<MediaPage> getMediaPage(MediaPageRequest request) async {
    pageCalls++;
    final start = request.page * request.pageSize;
    final end = math.min(start + request.pageSize, library.length);
    final items =
        start >= library.length ? <MediaItem>[] : library.sublist(start, end);
    return right<Failure, MediaPage>(
      MediaPage(items: items, hasMore: items.length == request.pageSize),
    );
  }

  @override
  FutureResult<int> getMediaCount(MediaKind kind) async =>
      right<Failure, int>(library.length);

  @override
  FutureResult<Uint8List?> getThumbnail(ThumbnailRequest request) async =>
      right<Failure, Uint8List?>(null);

  @override
  Stream<Result<Unit>> watchLibraryChanges() => changes.stream;
}

List<MediaItem> _library(int count) => [
      for (var i = 0; i < count; i++)
        _item('$i', DateTime(2026, 10, 29).subtract(Duration(days: i))),
    ];

ProviderContainer _containerWith(MutableFakeRepository repository) {
  final container = ProviderContainer(
    overrides: [mediaRepositoryProvider.overrideWithValue(repository)],
  );
  // Riverpod 3 pauses a provider nobody listens to. In the app the Photos page
  // listens; in a test we have to do it ourselves.
  final subscription =
  container.listen(photosControllerProvider, (previous, next) {});
  addTearDown(container.dispose);
  addTearDown(subscription.close);
  // Not awaited: closing a stream can wait forever for a paused listener.
  addTearDown(() => unawaited(repository.changes.close()));
  return container;
}

// The controller waits 600 ms before refreshing.
Future<void> _waitForRefresh() =>
    Future<void>.delayed(const Duration(milliseconds: 900));

void main() {
  test('a new photo is added with ONE page request (fast path)', () async {
    final repository = MutableFakeRepository(_library(5));
    final container = _containerWith(repository);
    final first = await container.read(photosControllerProvider.future);
    expect(first.items.length, 5);
    final callsBefore = repository.pageCalls;

    repository.library = [
      _item('new', DateTime(2026, 11)),
      ...repository.library,
    ];
    repository.notifyChange();
    await _waitForRefresh();

    final state = container.read(photosControllerProvider).requireValue;
    expect(state.items.length, 6);
    expect(state.items.first.id, 'new');
    expect(state.totalCount, 6);
    expect(repository.pageCalls - callsBefore, 1);
  });

  test('a deleted photo triggers a full reload', () async {
    final repository = MutableFakeRepository(_library(5));
    final container = _containerWith(repository);
    await container.read(photosControllerProvider.future);

    repository.library = repository.library.sublist(1); // newest one deleted
    repository.notifyChange();
    await _waitForRefresh();

    final state = container.read(photosControllerProvider).requireValue;
    expect(state.items.length, 4);
    expect(state.items.any((item) => item.id == '0'), isFalse);
  });

  test('many change events in a row still end with a refresh', () async {
    final repository = MutableFakeRepository(_library(5));
    final container = _containerWith(repository);
    await container.read(photosControllerProvider.future);

    repository.library = [
      _item('new', DateTime(2026, 11)),
      ...repository.library,
    ];
    // Events keep coming every 100 ms (a gallery app indexing in the background).
    for (var i = 0; i < 6; i++) {
      repository.notifyChange();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _waitForRefresh();

    final state = container.read(photosControllerProvider).requireValue;
    expect(state.items.first.id, 'new');
  });
}
