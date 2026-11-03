import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/navigation/last_tab_provider.dart';
import 'package:proalbums/app/router/app_keys.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/app/shell/main_shell_page.dart';
import 'package:proalbums/features/albums/presentation/pages/album_detail_page.dart';
import 'package:proalbums/features/albums/presentation/pages/album_picker_page.dart';
import 'package:proalbums/features/albums/presentation/pages/albums_page.dart';
import 'package:proalbums/features/albums/presentation/pages/change_cover_page.dart';
import 'package:proalbums/features/albums/presentation/pages/move_copy_page.dart';
import 'package:proalbums/features/albums/presentation/pages/other_albums_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/pages/photos_page.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_page_route.dart';
import 'package:proalbums/features/pdf/presentation/pages/convert_pdf_page.dart';
import 'package:proalbums/features/pdf/presentation/pages/pdf_adjust_image_page.dart';
import 'package:proalbums/features/pdf/presentation/pages/pdf_page_editor_page.dart';
import 'package:proalbums/features/permissions/presentation/pages/permission_page.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';
import 'package:proalbums/features/recommended/presentation/pages/for_you_page.dart';
import 'package:proalbums/features/search/presentation/pages/search_page.dart';
import 'package:proalbums/features/settings/presentation/screens/settings_screen.dart';
import 'package:proalbums/features/storage/presentation/pages/storage_analysis_page.dart';
import 'package:proalbums/features/trash/presentation/pages/recently_deleted_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// The router lives in a provider (not a global variable) so that its
/// `redirect` can `ref.watch` the permission state and send the user to the
/// permission screen automatically.
///
/// Rule: without media access EVERY screen except the permission screen is
/// closed (Settings included: it is opened from the ⋮ menu of a tab anyway).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // go_router re-runs `redirect` whenever this notifier changes.
  final permissionChanged = ValueNotifier<int>(0);
  ref.listen(
    mediaPermissionProvider,
    (previous, next) => permissionChanged.value++,
  );

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(lastTabProvider).path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: permissionChanged,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final hasAccess =
          ref.read(mediaPermissionProvider).value?.hasAccess ?? false;
      final onPermissionPage = location == AppRoutes.permission;

      if (!hasAccess) return onPermissionPage ? null : AppRoutes.permission;
      if (onPermissionPage) return ref.read(lastTabProvider).path;
      return null;
    },
    routes: [
      // Each branch keeps its own navigation stack and scroll position, so
      // switching tabs never rebuilds or loses the user's place.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.photos,
                builder: (context, state) => const PhotosPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.albums,
                builder: (context, state) => const AlbumsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.forYou,
                builder: (context, state) => const ForYouPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
        ],
      ),

      // ---- Full-screen pages: open above the bottom bar ------------------
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.permission,
        builder: (context, state) => const PermissionPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recentlyDeleted,
        builder: (context, state) => const RecentlyDeletedPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.storage,
        builder: (context, state) => const StorageAnalysisPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.otherAlbums,
        builder: (context, state) => const OtherAlbumsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.albumPattern,
        builder: (context, state) => AlbumDetailPage(
          albumId: state.pathParameters['albumId']!,
          title: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      // Returns the chosen picture's id: context.push<String>(...).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.changeCoverPattern,
        builder: (context, state) =>
            ChangeCoverPage(albumId: state.pathParameters['albumId']!),
      ),
      // Returns the chosen items: context.push<List<MediaItem>>(...).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pickItems,
        builder: (context, state) => AlbumPickerPage(
          maxCount: int.tryParse(state.uri.queryParameters['max'] ?? ''),
          imagesOnly: state.uri.queryParameters['images'] == '1',
        ),
      ),
      // Convert PDF: context.push(AppRoutes.convertPdf, extra: pictures).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.convertPdf,
        builder: (context, state) => ConvertPdfPage(
          items: switch (state.extra) {
            final List<MediaItem> items => items,
            _ => const <MediaItem>[],
          },
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfAdjustImage,
        builder: (context, state) => const PdfAdjustImagePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfEditPagePattern,
        builder: (context, state) =>
            PdfPageEditorPage(pageId: state.pathParameters['pageId']!),
      ),
      // Returns true when something was copied / moved:
      // context.push<bool>(AppRoutes.moveCopy(), extra: items).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.moveCopyPath,
        builder: (context, state) => MoveCopyPage(
          items: switch (state.extra) {
            final List<MediaItem> items => items,
            _ => const <MediaItem>[],
          },
          fromAlbumId: state.uri.queryParameters['from'],
        ),
      ),
      // The swipe list comes from ViewerSession (see open_media_viewer.dart).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.viewerPattern,
        pageBuilder: viewerPage,
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(permissionChanged.dispose);
  return router;
}
