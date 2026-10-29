import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/app/navigation/main_tab.dart';

void main() {
  group('MainTab.fromStorage', () {
    test('returns the saved tab', () {
      expect(MainTab.fromStorage('albums'), MainTab.albums);
      expect(MainTab.fromStorage('forYou'), MainTab.forYou);
    });

    test('falls back to photos for null or unknown values', () {
      expect(MainTab.fromStorage(null), MainTab.photos);
      expect(MainTab.fromStorage('settings'), MainTab.photos);
      expect(MainTab.fromStorage('1'), MainTab.photos);
    });

    test('storageValue round-trips for every tab', () {
      for (final tab in MainTab.values) {
        expect(MainTab.fromStorage(tab.storageValue), tab);
      }
    });
  });

  test('every tab has its own route path', () {
    final paths = MainTab.values.map((tab) => tab.path).toSet();
    expect(paths.length, MainTab.values.length);
  });
}
