import 'package:proalbums/core/utils/typedefs.dart';

/// Where the video file of an item can be played from.
abstract interface class VideoSourceRepository {
  /// Path of the video file, or null if the item is gone.
  FutureResult<String?> resolvePath(String id);
}
