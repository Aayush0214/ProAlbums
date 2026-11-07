import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/widgets/theme_selector_card.dart';
import 'package:proalbums/features/classification/presentation/classification_widgets.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_row.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_setting_tiles.dart';
import 'package:proalbums/features/settings/presentation/providers/app_version_provider.dart';
import 'package:proalbums/features/trash/presentation/widgets/recently_deleted_setting_tile.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_settings_tiles.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// Settings: the theme, then the options in groups (Viewing, Library,
/// Privacy, About). Options whose feature is not built yet are
/// shown greyed out with "Coming soon" — never a switch that does nothing.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('Settings', style: context.textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
        children: [
          const ThemeSelector(),
          const SizedBox(height: 10),
          const _Section(
            title: 'Viewing',
            children: [
              ViewerAutoplayTile(),
              ViewerKeepScreenOnTile(),
              ViewerAutoRotateTile(),
            ],
          ),
          const _Section(
            title: 'Library',
            children: [ClassificationSettingTile(), CleanupSettingTile()],
          ),
          const _Section(
            title: 'Privacy',
            children: [
              RecentlyDeletedSettingTile(),
              HiddenPhotosSettingTile(),
              VaultPasswordSettingTile(),
            ],
          ),
          _Section(
            title: 'About',
            children: [
              _ComingSoonTile(title: 'Check for updates', value: version),
              const _ComingSoonTile(title: 'About'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled group of options on one rounded card, with thin lines between
/// them.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              title,
              style: context.textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Material(
            clipBehavior: Clip.antiAlias,
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.dividerSubtle),
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that opens something not built yet: greyed out, saying so. [value]
/// is shown on the right (e.g. the version).
class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.title, this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final secondary = context.colors.textSecondary;
    return ListTile(
      enabled: false,
      title: Text(title),
      subtitle: const Text('Coming soon'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: context.textTheme.bodySmall),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 18, color: secondary),
        ],
      ),
    );
  }
}
