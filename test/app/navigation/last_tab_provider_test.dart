import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/app/navigation/last_tab_provider.dart';
import 'package:proalbums/app/navigation/main_tab.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:proalbums/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _createContainer(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts on photos when nothing was saved', () async {
    final container = await _createContainer({});

    expect(container.read(lastTabProvider), MainTab.photos);
  });

  test('starts on the saved tab', () async {
    final container = await _createContainer({
      StorageKeys.lastMainTab: 'albums',
    });

    expect(container.read(lastTabProvider), MainTab.albums);
  });

  test('select updates the state and saves it to disk', () async {
    final container = await _createContainer({});

    container.read(lastTabProvider.notifier).select(MainTab.search);
    await Future<void>.delayed(Duration.zero); // let the save finish

    expect(container.read(lastTabProvider), MainTab.search);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.lastMainTab), 'search');
  });

  test('a corrupted saved value falls back to photos', () async {
    final container = await _createContainer({
      StorageKeys.lastMainTab: 'not-a-tab',
    });

    expect(container.read(lastTabProvider), MainTab.photos);
  });
}
