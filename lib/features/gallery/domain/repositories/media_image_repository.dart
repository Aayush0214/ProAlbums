import 'dart:typed_data';

import 'package:proalbums/core/utils/typedefs.dart';

/// Pictures big enough to fill the photo viewer (not the small grid tiles).
abstract interface class MediaImageRepository {
  /// JPEG bytes of the photo, scaled so its LONGER side is at most
  /// [maxLongEdge] pixels (never enlarged). null if the item is gone.
  FutureResult<Uint8List?> loadDisplayImage({
    required String id,
    required int maxLongEdge,
  });
}
