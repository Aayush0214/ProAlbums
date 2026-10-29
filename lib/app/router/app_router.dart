import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/navigation/last_tab_provider.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/app/shell/main_shell_page.dart';
import 'package:proalbums/features/albums/presentation/pages/albums_page.dart';
import 'package:proalbums/features/gallery/presentation/pages/photos_page.dart';
import 'package:proalbums/features/permissions/presentation/pages/permission_page.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';
import 'package:proalbums/features/recommended/presentation/pages/for_you_page.dart';
import 'package:proalbums/features/search/presentation/pages/search_page.dart';
import 'package:proalbums/features/settings/presentation/screens/settings_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// The router lives in a provider (not a global variable) so that, in Phase 1,
/// its `redirect` can `ref.watch` the permission state and send the user to the
/// permission screen automatically.
///
final _rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // go_router re-runs `redirect` whenever this notifier changes.
  final permissionChanged = ValueNotifier<int>(0);
  ref.listen(mediaPermissionProvider, (previous, next) => permissionChanged.value++);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(lastTabProvider).path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: permissionChanged,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == AppRoutes.settings) return null; // works without media access

      final hasAccess = ref.read(mediaPermissionProvider).value?.hasAccess ?? false;
      final onPermissionPage = location == AppRoutes.permission;

      if (!hasAccess) return onPermissionPage ? null : AppRoutes.permission;
      if (onPermissionPage) return ref.read(lastTabProvider).path;  // was: AppRoutes.photos
      return null;
    },
    routes: [
      // Each branch keeps its own navigation stack and scroll position, so
      // switching tabs never rebuilds or loses the user's place.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShellPage(navigationShell: navigationShell),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.permission,
        builder: (context, state) => const PermissionPage(),
      ),
      // Full-screen Settings Route (pushed over the bottom navigation bar)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(permissionChanged.dispose);
  return router;
}
