import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/shared/widgets/glass_container.dart';

/// The frame around the 4 main tabs: Photos, Albums, For You, Search.
/// go_router gives us [navigationShell] (the currently visible tab).
class MainShellPage extends StatelessWidget {
  const MainShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_TabItem> _tabs = [
    _TabItem('Photos', LucideIcons.image),
    _TabItem('Albums', LucideIcons.folder),
    _TabItem('For You', LucideIcons.sparkles),
    _TabItem('Search', LucideIcons.search),
  ];

  void _onTabSelected(int index) {
    // Tapping the tab you are already on goes back to that tab's first page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content scrolls BEHIND the glass nav bar. The body's
      // MediaQuery.padding.bottom automatically includes the bar height, so
      // scrollable just need `padding: MediaQuery.paddingOf(context)`.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassContainer(
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon);
  final String label;
  final IconData icon;
}
