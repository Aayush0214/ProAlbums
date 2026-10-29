import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/features/gallery/data/datasources/media_local_data_source.dart';
import 'package:proalbums/features/gallery/data/repositories/media_repository_impl.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';

class MockMediaDataSource extends Mock implements MediaLocalDataSource {}

void main() {
  late MockMediaDataSource dataSource;
  late MediaRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(MediaKind.all);
    registerFallbackValue(MediaSortOrder.newestFirst);
  });

  setUp(() {
    dataSource = MockMediaDataSource();
    repository = MediaRepositoryImpl(dataSource);
  });

  void stubGetAssets(Future<List<AssetEntity>> Function() answer) {
    when(
      () => dataSource.getAssets(
        page: any(named: 'page'),
        size: any(named: 'size'),
        kind: any(named: 'kind'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) => answer());
  }

  group('getMediaPage', () {
    test('maps assets to MediaItems and reports hasMore for a full page', () async {
      stubGetAssets(
        () async => [
          AssetEntity(
            id: '1',
            typeInt: 1, // image
            width: 1080,
            height: 1920,
            createDateSecond: 1700000000,
          ),
          AssetEntity(
            id: '2',
            typeInt: 2, // video
            width: 1920,
            height: 1080,
            duration: 12,
            createDateSecond: 1700000100,
          ),
        ],
      );

      final result = await repository.getMediaPage(
        const MediaPageRequest(page: 0, pageSize: 2),
      );

      result.match(
        (failure) => fail('Expected success but got $failure'),
        (page) {
          expect(page.hasMore, isTrue);
          expect(page.items.map((item) => item.id), ['1', '2']);
          expect(page.items[0].type, MediaType.image);
          expect(page.items[1].type, MediaType.video);
          expect(page.items[1].duration, const Duration(seconds: 12));
        },
      );
    });

    test('hasMore is false when the page is not full', () async {
      stubGetAssets(() async => const <AssetEntity>[]);

      final result = await repository.getMediaPage(
        const MediaPageRequest(page: 3, pageSize: 100),
      );

      result.match(
        (failure) => fail('Expected success but got $failure'),
        (page) {
          expect(page.items, isEmpty);
          expect(page.hasMore, isFalse);
        },
      );
    });

    test('returns a MediaFailure when the plugin throws', () async {
      stubGetAssets(() async => throw Exception('boom'));

      final result = await repository.getMediaPage(
        const MediaPageRequest(page: 0),
      );

      result.match(
        (failure) => expect(failure, isA<MediaFailure>()),
        (_) => fail('Expected a failure'),
      );
    });
  });

  group('getMediaCount', () {
    test('returns the count from the data source', () async {
      when(() => dataSource.getCount(any())).thenAnswer((_) async => 2660);

      final result = await repository.getMediaCount(MediaKind.all);

      result.match(
        (failure) => fail('Expected success but got $failure'),
        (count) => expect(count, 2660),
      );
    });
  });
}
