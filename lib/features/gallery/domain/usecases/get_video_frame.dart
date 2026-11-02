import 'dart:typed_data';

import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_frame_repository.dart';

/// One picture of a video at a moment in time.
final class GetVideoFrameUseCase {
  const GetVideoFrameUseCase(this._repository);

  final VideoFrameRepository _repository;

  FutureResult<Uint8List?> call({
    required String id,
    required Duration position,
    required int size,
  }) =>
      _repository.frameAt(id: id, position: position, size: size);
}
