import 'dart:async';

import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:proalbums/features/gallery/data/repositories/shared_prefs_photos_view_settings_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/domain/repositories/photos_view_settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_view_settings_controller.g.dart';

@Riverpod(keepAlive: true)
PhotosViewSettingsRepository photosViewSettingsRepository(Ref ref) =>
    SharedPrefsPhotosViewSettingsRepository(ref.watch(sharedPreferencesProvider));

/// Zoom level, browsing order and immersive view of the Photos tab.
/// Starts with the SAVED values and saves every change.
@Riverpod(keepAlive: true)
class PhotosViewSettingsController extends _$PhotosViewSettingsController {
  @override
  PhotosViewSettings build() =>
      ref.read(photosViewSettingsRepositoryProvider).read();

  /// Fewer columns = bigger photos.
  void zoomIn() {
    if (state.canZoomIn) _update(state.copyWith(columns: state.columnsZoomedIn));
  }

  void zoomOut() {
    if (state.canZoomOut) _update(state.copyWith(columns: state.columnsZoomedOut));
  }

  void setOrder(MediaSortOrder order) => _update(state.copyWith(order: order));

  void setImmersive({required bool enabled}) =>
      _update(state.copyWith(immersive: enabled));

  void _update(PhotosViewSettings next) {
    if (next == state) return;
    state = next;
    // Fire and forget: the repository never throws, and the UI must not wait
    // for a disk write.
    unawaited(ref.read(photosViewSettingsRepositoryProvider).save(next));
  }
}
