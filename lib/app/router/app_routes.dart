/// All route paths in one place. Never type a path string inside a widget.
abstract final class AppRoutes {
  // Tabs (inside the bottom bar)
  static const String photos = '/photos';
  static const String albums = '/albums';
  static const String forYou = '/for-you';
  static const String search = '/search';

  // Full-screen pages (open above the bottom bar)
  static const String settings = '/settings';
  static const String permission = '/permission';
  static const String recentlyDeleted = '/recently-deleted';
  static const String storage = '/storage';
  static const String otherAlbums = '/other-albums';
  static const String pickItems = '/pick-items';

  // Pages with a parameter. The *Pattern is for the router, the function
  // builds the real path (ids are encoded, so any id is safe).
  static const String albumPattern = '/album/:albumId';
  static const String changeCoverPattern = '/change-cover/:albumId';
  static const String viewerPattern = '/viewer/:mediaId';

  /// [name] is only the title shown on top; the album is found by [id].
  static String album(String id, String name) =>
      '/album/${Uri.encodeComponent(id)}'
      '?${Uri(queryParameters: {'name': name}).query}';

  static String changeCover(String albumId) =>
      '/change-cover/${Uri.encodeComponent(albumId)}';

  static String viewer(String mediaId) =>
      '/viewer/${Uri.encodeComponent(mediaId)}';
}
