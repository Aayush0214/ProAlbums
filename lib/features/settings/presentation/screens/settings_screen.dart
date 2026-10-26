import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/widgets/theme_selector_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: context.textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        children: [
          /// Theme selector
          const ThemeSelector(),
          const SizedBox(height: 10),

          /// Setting Options
          Material(
            clipBehavior: Clip.antiAlias,
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ext.dividerSubtle),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Autoplay Videos'),
                    subtitle: const Text('Videos are muted by default when autoplaying.'),
                    value: false,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Live photo autoplay'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Intelligent classification'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Cleanup suggestions'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Recently deleted'),
                    subtitle: const Text('Deleted images and videos will be displayed in "Recently deleted".'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Save method after editing'),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: ext.textSecondary),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Keep screen on while viewing'),
                    value: false,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Auto-rotate when viewing photos'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Always', style: context.textTheme.bodySmall),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 18, color: ext.textSecondary),
                      ],
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Hidden photos'),
                    subtitle: const Text('Show hidden images and videos.'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Encrypted', style: context.textTheme.bodySmall),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 18, color: ext.textSecondary),
                      ],
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Password for hidden photos'),
                    subtitle: const Text('Privacy password is required for verification'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Check for updates'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('V1.0.1', style: context.textTheme.bodySmall),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 18, color: ext.textSecondary),
                      ],
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('About'),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: ext.textSecondary),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

