import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/result_guard.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/data/datasources/media_local_data_source.dart';
import 'package:proalbums/features/gallery/data/mappers/media_item_mapper.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';

final class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl(this._dataSource);

  final MediaLocalDataSource _dataSource;

  @override
  FutureResult<MediaPage> getMediaPage(MediaPageRequest request) => guardAsync(
        () async {
          final assets = await _dataSource.getAssets(
            page: request.page,
            size: request.pageSize,
            kind: request.kind,
            order: request.order,
          );
          return MediaPage(
            items: assets.map(MediaItemMapper.fromAsset).toList(growable: false),
            // A full page means there may be more. (If the library size is an
            // exact multiple of pageSize, the next call just returns empty.)
            hasMore: assets.length == request.pageSize,
          );
        },
        onError: (error, stackTrace) => MediaFailure(
          'Could not load photos and videos.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  FutureResult<int> getMediaCount(MediaKind kind) => guardAsync(
        () => _dataSource.getCount(kind),
        onError: (error, stackTrace) => MediaFailure(
          'Could not count photos and videos.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  FutureResult<Uint8List?> getThumbnail(ThumbnailRequest request) => guardAsync(
        () => _dataSource.getThumbnail(id: request.id, size: request.size),
        onError: (error, stackTrace) => MediaFailure(
          'Could not load a preview.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  Stream<Result<Unit>> watchLibraryChanges() => _dataSource.libraryChanges
      .map((_) => right<Failure, Unit>(unit));
}
