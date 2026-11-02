import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';

abstract interface class MediaDetailsRepository {
  /// null when the item no longer exists.
  FutureResult<MediaDetails?> load(String id);
}
