import 'dart:typed_data';

import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_image_repository.dart';

/// Load the picture shown in the photo viewer.
final class LoadDisplayImageUseCase {
  const LoadDisplayImageUseCase(this._repository);

  final MediaImageRepository _repository;

  FutureResult<Uint8List?> call({
    required String id,
    required int maxLongEdge,
  }) =>
      _repository.loadDisplayImage(id: id, maxLongEdge: maxLongEdge);
}
