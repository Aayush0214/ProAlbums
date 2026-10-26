import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/app/shell/main_shell_page.dart';
import 'package:proalbums/features/albums/presentation/pages/albums_page.dart';
import 'package:proalbums/features/gallery/presentation/pages/photos_page.dart';
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
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.photos,
    debugLogDiagnostics: kDebugMode,
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
      // Full-screen Settings Route (pushed over the bottom navigation bar)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
