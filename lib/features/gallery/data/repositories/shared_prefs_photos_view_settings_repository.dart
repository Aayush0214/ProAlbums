import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/gallery/data/preferences/photos_preference_keys.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/domain/repositories/photos_view_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPrefsPhotosViewSettingsRepository
    implements PhotosViewSettingsRepository {
  const SharedPrefsPhotosViewSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  PhotosViewSettings read() {
    // Whatever is on disk, the result is always valid: a corrupted or old value
    // is moved to the nearest zoom level / replaced by the default, it can never break the screen.
    final savedColumns =
        _prefs.getInt(PhotosPreferenceKeys.columns) ?? PhotosViewSettings.defaultColumns;
    final columns = PhotosViewSettings.snapToStep(savedColumns);

    final order = MediaSortOrder.values.asNameMap()[
            _prefs.getString(PhotosPreferenceKeys.order)] ??
        MediaSortOrder.newestFirst;

    return PhotosViewSettings(
      columns: columns,
      order: order,
      immersive: _prefs.getBool(PhotosPreferenceKeys.immersive) ?? false,
    );
  }

  @override
  Future<void> save(PhotosViewSettings settings) async {
    try {
      await Future.wait([
        _prefs.setInt(PhotosPreferenceKeys.columns, settings.columns),
        _prefs.setString(PhotosPreferenceKeys.order, settings.order.name),
        _prefs.setBool(PhotosPreferenceKeys.immersive, settings.immersive),
      ]);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Could not save the Photos view settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
