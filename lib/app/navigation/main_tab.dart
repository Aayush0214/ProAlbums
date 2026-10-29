import 'package:proalbums/app/router/app_routes.dart';

/// The 4 tabs of the bottom navigation bar.
///
/// RULE: the ORDER of these values must be the same as the order of the
/// StatefulShellBranch list in app_router.dart. The shell page asserts this
/// in debug mode, so a mistake is caught immediately.
enum MainTab {
  photos(AppRoutes.photos),
  albums(AppRoutes.albums),
  forYou(AppRoutes.forYou),
  search(AppRoutes.search);

  const MainTab(this.path);

  /// Route that opens this tab.
  final String path;

  /// Value saved on disk = the enum NAME ('albums'), not the index (1).
  /// WHY: if we ever reorder or add tabs, an old saved index would open the
  /// wrong tab. A name keeps meaning the same tab forever.
  String get storageValue => name;

  /// Reads a saved value. Missing or unknown values fall back to [photos],
  /// so old/corrupted data can never crash or block the app from opening.
  static MainTab fromStorage(String? value) =>
      MainTab.values.asNameMap()[value] ?? MainTab.photos;
}
