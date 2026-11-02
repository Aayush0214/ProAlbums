import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'recently_deleted_setting.g.dart';

const String _key = 'recently_deleted_enabled';

/// Settings > "Recently deleted".
///  - ON (default): a delete moves the items to Android's trash for 30 days.
///  - OFF: a delete removes them for good, and the "Recently deleted" row is
///    hidden.
///
/// Only SAVES the choice. Turning it off also empties the trash: that part
/// needs the screen (a dialog), so it lives in `turnOffRecentlyDeleted`.
@Riverpod(keepAlive: true)
class RecentlyDeletedEnabled extends _$RecentlyDeletedEnabled {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> save({required bool enabled}) async {
    state = AsyncData(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } on Object {
      // Not saved: it is back to the default the next time the app starts.
    }
  }
}
