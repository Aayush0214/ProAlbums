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

/// A fake gallery with [total] photos, newest first, one per day.
/// [shuffleDates] mimics a phone whose MediaStore order (date added) differs
/// from the date we show (date taken).
class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository(
    this.total, {
    this.failPages = false,
    this.shuffleDates = false,
  });

  final int total;
  final bool failPages;
  final bool shuffleDates;

  MediaItem _item(int index) {
    // Every 3rd photo was TAKEN a few days earlier than its position says.
    final dayOffset = shuffleDates && index % 3 == 0 ? index + 5 : index;
    return MediaItem(
      id: '$index',
      type: MediaType.image,
      createdAt: DateTime(2026, 10, 29).subtract(Duration(days: dayOffset)),
      width: 100,
      height: 100,
    );
  }

  @override
  FutureResult<MediaPage> getMediaPage(MediaPageRequest request) async {
    if (failPages) return left<Failure, MediaPage>(const MediaFailure('boom'));
    final start = request.page * request.pageSize;
    final end = math.min(start + request.pageSize, total);
    final items = [for (var i = start; i < end; i++) _item(i)];
    return right<Failure, MediaPage>(
      MediaPage(items: items, hasMore: items.length == request.pageSize),
    );
  }

  @override
  FutureResult<int> getMediaCount(MediaKind kind) async =>
      right<Failure, int>(total);

  @override
  FutureResult<Uint8List?> getThumbnail(ThumbnailRequest request) async =>
      right<Failure, Uint8List?>(null);

  @override
  Stream<Result<Unit>> watchLibraryChanges() => const Stream.empty();
}

ProviderContainer _containerWith(FakeMediaRepository repository) {
  final container = ProviderContainer(
    // Riverpod 3 RETRIES a failed provider again and again by default, so in
    // a test the error would never arrive. We want to see the first error.
    retry: (retryCount, error) => null,
    overrides: [mediaRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('shows the first page first, then loads the rest in the background', () async {
    final container = _containerWith(FakeMediaRepository(650));

    final first = await container.read(photosControllerProvider.future);

    expect(first.items.length, 300);
    expect(first.totalCount, 650);
    expect(first.isLoadingMore, isTrue);

    await pumpEventQueue(); // lets the background pages finish

    final done = container.read(photosControllerProvider).requireValue;
    expect(done.items.length, 650);
    expect(done.totalCount, 650);
    expect(done.isLoadingMore, isFalse);
    // order is kept: newest (index 0) first
    expect(done.items.first.id, '0');
    expect(done.items.last.id, '649');
  });

  test('items are sorted by the date shown, even if the phone sorts differently', () async {
    final container = _containerWith(
      FakeMediaRepository(650, shuffleDates: true),
    );

    await container.read(photosControllerProvider.future);
    await pumpEventQueue();

    final items = container.read(photosControllerProvider).requireValue.items;
    expect(items.length, 650);
    for (var i = 1; i < items.length; i++) {
      expect(
        items[i - 1].createdAt.isBefore(items[i].createdAt),
        isFalse,
        reason: 'item $i is newer than the one before it',
      );
    }
  });

  test('a small library needs just one page', () async {
    final container = _containerWith(FakeMediaRepository(40));

    final state = await container.read(photosControllerProvider.future);

    expect(state.items.length, 40);
    expect(state.isLoadingMore, isFalse);
  });

  test('an empty library gives an empty list, not an error', () async {
    final container = _containerWith(FakeMediaRepository(0));

    final state = await container.read(photosControllerProvider.future);

    expect(state.items, isEmpty);
    expect(state.isLoadingMore, isFalse);
  });

  test('a failing first page becomes an error', () async {
    final container = _containerWith(FakeMediaRepository(10, failPages: true));

    await expectLater(
      container.read(photosControllerProvider.future),
      throwsA(isA<MediaFailure>()),
    );
  });
}
