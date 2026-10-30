import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:proalbums/features/gallery/data/preferences/photos_preference_keys.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_view_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts with the saved zoom level', () async {
    final c = await _container({PhotosPreferenceKeys.columns: 6});
    expect(c.read(photosViewSettingsControllerProvider).columns, 6);
  });

  test('zoom in never goes below the minimum', () async {
    final c = await _container({});
    final n = c.read(photosViewSettingsControllerProvider.notifier);
    for (var i = 0; i < 10; i++) {
      n.zoomIn();
    }
    expect(
      c.read(photosViewSettingsControllerProvider).columns,
      PhotosViewSettings.minColumns,
    );
  });

  test('zoom out never goes above the maximum and is saved', () async {
    final c = await _container({});
    final n = c.read(photosViewSettingsControllerProvider.notifier);
    for (var i = 0; i < 10; i++) {
      n.zoomOut();
    }
    await Future<void>.delayed(Duration.zero);

    expect(
      c.read(photosViewSettingsControllerProvider).columns,
      PhotosViewSettings.maxColumns,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(PhotosPreferenceKeys.columns), PhotosViewSettings.maxColumns);
  });
}
