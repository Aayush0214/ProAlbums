import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';

/// Remembers the Photos tab look. Contract only (see last_tab_repository.dart
/// for the same idea).
abstract interface class PhotosViewSettingsRepository {
  /// Synchronous on purpose: preferences are loaded in main(), so the very
  /// first frame already has the right zoom level.
  PhotosViewSettings read();

  /// Never throws: losing a view setting is harmless.
  Future<void> save(PhotosViewSettings settings);
}
