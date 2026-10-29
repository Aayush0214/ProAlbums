import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';

/// Read-side contract of the device gallery. (Delete / favorite / trash get
/// their own methods in Phase 4.)
abstract interface class MediaRepository {
  FutureResult<MediaPage> getMediaPage(MediaPageRequest request);

  FutureResult<int> getMediaCount(MediaKind kind);

  /// JPEG bytes of a small preview, or null if the item no longer exists.
  FutureResult<Uint8List?> getThumbnail(ThumbnailRequest request);

  /// Emits whenever photos/videos are added, removed or changed on the device.
  Stream<Result<Unit>> watchLibraryChanges();
}
