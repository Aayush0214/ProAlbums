import 'package:proalbums/app/navigation/main_tab.dart';

/// Remembers which tab the user was on. Contract only; the storage detail
/// (SharedPreferences today) can change without touching the router or UI.
abstract interface class LastTabRepository {
  /// Synchronous on purpose: SharedPreferences is already loaded in main(),
  /// so the router can know the start tab BEFORE the first frame (no flicker).
  MainTab read();

  /// Never throws. Losing this value is harmless, so a failed save must not
  /// disturb the user.
  Future<void> save(MainTab tab);
}
