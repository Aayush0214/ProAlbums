/// All route paths in one place. Never type a path string inside a widget.
abstract final class AppRoutes {
  // Tabs (inside the bottom bar)
  static const String photos = '/photos';
  static const String albums = '/albums';
  static const String forYou = '/for-you';
  static const String search = '/search';

  /// Typing a search (a page inside the Search tab).
  static const String searchQuerySegment = 'query';
  static const String searchQuery = '/search/query';

  // Full-screen pages (open above the bottom bar)
  static const String settings = '/settings';
  static const String permission = '/permission';
  static const String recentlyDeleted = '/recently-deleted';
  static const String storage = '/storage';
  static const String otherAlbums = '/other-albums';
  static const String pickItems = '/pick-items';

  /// The items go as `extra` (a `List<MediaItem>`): too many for a URL.
  static const String moveCopyPath = '/move-copy';

  /// Convert PDF: the pictures go as `extra` (a `List<MediaItem>`).
  static const String convertPdf = '/convert-pdf';

  /// Adjust image (the pages of the PDF being made, as a grid).
  static const String pdfAdjustImage = '/convert-pdf/adjust';

  /// Private vault: "Hidden photos" (only from Settings) and its security
  /// steps. The Recovery Key goes as `extra` (a String), never in the URL.
  static const String vault = '/vault';
  static const String vaultSetup = '/vault/setup';
  static const String vaultRecoveryKey = '/vault/recovery-key';
  static const String vaultForgot = '/vault/forgot';

  /// Restore hidden items from the vault folder (after a reinstall); the
  /// number of items found goes as `extra` (an int).
  static const String vaultRestore = '/vault/restore';

  /// The full-screen video player over the viewer; `extra` is a
  /// VideoPlayerRequest (the video, and whether the screen was turned).
  static const String videoPlayer = '/video-player';

  /// Compress size of a video (progress, then the new copy); `extra` is a
  /// CompressVideoRequest.
  static const String compressVideo = '/compress-video';

  /// Slideshow from the viewer; `extra` is the id of the picture to start at.
  static const String slideshow = '/slideshow';

  /// Grid > Collage; `extra` is the pictures (`List<MediaItem>`). Pops with the
  /// saved collage's id (or null).
  static const String collage = '/collage';

  /// Albums > Cleanup suggestions; its sets (`extra` = CleanupKind) and the
  /// big preview of a picture (`extra` = CleanupPreviewRequest).
  static const String cleanup = '/cleanup';
  static const String cleanupGroups = '/cleanup/sets';
  static const String cleanupPreview = '/cleanup/preview';

  /// Albums > Intelligent classification ("More"), People, and People's
  /// "+" (the other people found).
  static const String classification = '/classification';
  static const String people = '/people';
  static const String addPeople = '/people/add';

  /// Intelligent classification > Location (the places).
  static const String locations = '/locations';

  // Pages with a parameter. The *Pattern is for the router, the function
  // builds the real path (ids are encoded, so any id is safe).
  static const String albumPattern = '/album/:albumId';
  static const String changeCoverPattern = '/change-cover/:albumId';
  static const String viewerPattern = '/viewer/:mediaId';
  static const String pdfEditPagePattern = '/convert-pdf/edit/:pageId';
  static const String personPattern = '/person/:personId';

  /// One person's page (People).
  static String person(int personId) => '/person/$personId';

  /// The People page opened from the Search tab (a person = plain grid).
  static const String searchPeople = '/search-people';

  /// For You > Memories > More.
  static const String memories = '/memories';

  static const String memoryGalleryPattern = '/memory/:memoryId';

  /// A memory's pictures (View Gallery).
  static String memoryGallery(int memoryId) => '/memory/$memoryId';

  static const String memoryPlayerPattern = '/memory/:memoryId/play';

  /// A memory's video.
  static String memoryPlayer(int memoryId) => '/memory/$memoryId/play';

  static const String memoryManagePattern = '/memory/:memoryId/manage';

  /// A memory's Gallery management.
  static String memoryManage(int memoryId) => '/memory/$memoryId/manage';

  /// "Choose a part" of the user's song (extra: MusicTrimRequest).
  static const String memoryMusicTrim = '/memory-music-trim';

  /// For You > Featured > More.
  static const String featured = '/featured';

  /// A Search result (extra: SearchTarget).
  static const String searchResult = '/search-result';

  static const String thingPattern = '/thing/:kind';

  /// One thing's pictures (Documents, Food…); [kind] is a ThingKind name.
  static String thing(String kind) => '/thing/${Uri.encodeComponent(kind)}';

  static const String placePattern = '/place/:name';

  /// One place's pictures (Location).
  static String place(String name) => '/place/${Uri.encodeComponent(name)}';

  /// Crop & rotate one page of the PDF being made.
  static String pdfEditPage(String pageId) =>
      '/convert-pdf/edit/${Uri.encodeComponent(pageId)}';

  /// [name] is only the title shown on top; the album is found by [id].
  static String album(String id, String name) =>
      '/album/${Uri.encodeComponent(id)}'
      '?${Uri(queryParameters: {'name': name}).query}';

  /// [fromAlbumId]: the album the items come from (not offered as a target).
  static String moveCopy({String? fromAlbumId}) => fromAlbumId == null
      ? moveCopyPath
      : '$moveCopyPath?${Uri(queryParameters: {'from': fromAlbumId}).query}';

  /// "Select items" with at most [max] items, only pictures when
  /// [imagesOnly].
  static String pickItemsWith({int? max, bool imagesOnly = false}) {
    final query = <String, String>{
      if (max != null) 'max': '$max',
      if (imagesOnly) 'images': '1',
    };
    return query.isEmpty
        ? pickItems
        : '$pickItems?${Uri(queryParameters: query).query}';
  }

  static String changeCover(String albumId) =>
      '/change-cover/${Uri.encodeComponent(albumId)}';

  static String viewer(String mediaId) =>
      '/viewer/${Uri.encodeComponent(mediaId)}';
}
