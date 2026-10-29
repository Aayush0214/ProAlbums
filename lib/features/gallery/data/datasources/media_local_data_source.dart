import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';

/// What the repository needs from the device gallery. The real implementation
/// uses photo_manager; unit tests use a fake.
abstract interface class MediaLocalDataSource {
  Future<List<AssetEntity>> getAssets({
    required int page,
    required int size,
    required MediaKind kind,
    required MediaSortOrder order,
  });

  Future<int> getCount(MediaKind kind);

  Future<Uint8List?> getThumbnail({required String id, required int size});

  /// Fires (without data) every time the device library changes.
  Stream<void> get libraryChanges;
}
