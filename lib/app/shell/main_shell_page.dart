import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/navigation/last_tab_provider.dart';
import 'package:proalbums/app/navigation/main_tab.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/shared/shell/shell_bottom_bar_provider.dart';
import 'package:proalbums/shared/widgets/glass_container.dart';

/// The frame around the 4 main tabs: Photos, Albums, For You, Search.
/// go_router gives us [navigationShell] (the currently visible tab).
class MainShellPage extends ConsumerWidget {
  const MainShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTabSelected(WidgetRef ref, int index) {
    ref.read(lastTabProvider.notifier).select(MainTab.values[index]);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      navigationShell.route.branches.length == MainTab.values.length,
      'Router branches and MainTab must be in the same order.',
    );
    // A tab can hide the bar (photo selection shows its own action bar).
    final barHidden = ref.watch(shellBottomBarHiddenProvider);

    return Scaffold(
      // Content scrolls BEHIND the glass nav bar. The body's
      // MediaQuery.padding.bottom automatically includes the bar height, so
      // scrollable just need `padding: MediaQuery.paddingOf(context)`.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: barHidden
          ? null
          : GlassContainer(
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => _onTabSelected(ref, index),
                destinations: [
                  for (final tab in MainTab.values)
                    NavigationDestination(
                      label: tab.label,
                      icon: Icon(tab.icon),
                      selectedIcon:
                          Icon(tab.icon, color: context.colors.activeAccent),
                    ),
                ],
              ),
            ),
    );
  }
}

extension on MainTab {
  String get label => switch (this) {
    MainTab.photos => 'Photos',
    MainTab.albums => 'Albums',
    MainTab.forYou => 'For You',
    MainTab.search => 'Search',
  };

  IconData get icon => switch (this) {
    MainTab.photos => LucideIcons.image,
    MainTab.albums => LucideIcons.folder,
    MainTab.forYou => LucideIcons.sparkles,
    MainTab.search => LucideIcons.search,
  };
}
