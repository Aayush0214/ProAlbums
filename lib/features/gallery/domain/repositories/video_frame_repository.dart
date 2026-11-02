import 'dart:typed_data';

import 'package:proalbums/core/utils/typedefs.dart';

/// Single pictures taken out of a video (for the strip under the player).
abstract interface class VideoFrameRepository {
  /// JPEG of the frame near [position], longer side at most [size] pixels.
  /// null when it cannot be made (the strip then shows a plain box).
  FutureResult<Uint8List?> frameAt({
    required String id,
    required Duration position,
    required int size,
  });
}
