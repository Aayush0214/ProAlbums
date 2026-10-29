import 'dart:typed_data';

import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';

final class GetMediaThumbnail implements UseCase<Uint8List?, ThumbnailRequest> {
  const GetMediaThumbnail(this._repository);

  final MediaRepository _repository;

  @override
  FutureResult<Uint8List?> call(ThumbnailRequest params) =>
      _repository.getThumbnail(params);
}
