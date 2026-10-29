import 'package:proalbums/app/navigation/last_tab_repository.dart';
import 'package:proalbums/app/navigation/main_tab.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPrefsLastTabRepository implements LastTabRepository {
  const SharedPrefsLastTabRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  MainTab read() =>
      MainTab.fromStorage(_prefs.getString(StorageKeys.lastMainTab));

  @override
  Future<void> save(MainTab tab) async {
    try {
      await _prefs.setString(StorageKeys.lastMainTab, tab.storageValue);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Could not save the last tab',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
