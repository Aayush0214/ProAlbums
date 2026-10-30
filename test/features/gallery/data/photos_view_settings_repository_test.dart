import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/data/preferences/photos_preference_keys.dart';
import 'package:proalbums/features/gallery/data/repositories/shared_prefs_photos_view_settings_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPrefsPhotosViewSettingsRepository> _repo(
  Map<String, Object> saved,
) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPrefsPhotosViewSettingsRepository(
    await SharedPreferences.getInstance(),
  );
}

void main() {
  test('nothing saved gives the defaults', () async {
    final repo = await _repo({});
    expect(repo.read(), const PhotosViewSettings());
  });

  test('save then read round-trips', () async {
    final repo = await _repo({});
    const settings = PhotosViewSettings(
      columns: 6,
      order: MediaSortOrder.oldestFirst,
      immersive: true,
    );

    await repo.save(settings);

    expect(repo.read(), settings);
  });

  test('an old 5 or 7 column value snaps to a valid zoom level', () async {
    expect((await _repo({PhotosPreferenceKeys.columns: 5})).read().columns, 4);
    expect((await _repo({PhotosPreferenceKeys.columns: 7})).read().columns, 6);
  });

  test('bad saved values are clamped or replaced', () async {
    final repo = await _repo({
      PhotosPreferenceKeys.columns: 99,
      PhotosPreferenceKeys.order: 'sideways',
    });

    final s = repo.read();
    expect(s.columns, PhotosViewSettings.maxColumns);
    expect(s.order, MediaSortOrder.newestFirst);
  });
}
