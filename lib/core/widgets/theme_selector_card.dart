import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/theme_notifier.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.colors;
    final currentMode = ref.watch(themeModeProvider);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: .circular(16),
        side: BorderSide(color: ext.dividerSubtle),
      ),
      child: Column(
        mainAxisAlignment: .start,
        children: [
          ListTile(
            leading: Icon(LucideIcons.palette, color: ext.activeAccent),
            title: Text('Theme Mode', style: context.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Choose your visual preference'),
            trailing: Card(
              margin: EdgeInsets.zero,
              color: ext.accentTintedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: .circular(16),
                side: BorderSide(color: ext.accentTintedSurface),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Active: ${currentMode.name.toUpperCase()}',
                  style: context.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: ext.activeAccent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              crossAxisAlignment: .center,
              children: [
                Expanded(
                  child: _ThemeOptionCard(
                    ext: ext,
                    title: 'System',
                    icon: LucideIcons.cog,
                    subTitle: 'Auto matched',
                    isActive: currentMode.isSystem,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeOptionCard(
                    ext: ext,
                    title: 'Light',
                    icon: LucideIcons.sun,
                    subTitle: 'Daylight clear',
                    isActive: currentMode.isLight,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeOptionCard(
                    ext: ext,
                    title: 'Dark',
                    subTitle: 'OLED Dark',
                    icon: LucideIcons.moon,
                    isActive: currentMode.isDark,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final AppColorExtension ext;
  final String title;
  final String subTitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ThemeOptionCard({
    required this.ext,
    required this.title,
    required this.subTitle,
    required this.icon,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: isActive ? ext.accentTintedSurface.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: .circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: .circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: .circular(16),
                  border: Border.all(
                    color: isActive ? ext.activeAccent : ext.dividerSubtle,
                    width: isActive ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? ext.activeAccent
                            : ext.surfaceContainerLow,
                        border: Border.all(
                          color: isActive
                              ? ext.activeAccent
                              : ext.dividerSubtle,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isActive ? Colors.white : ext.textSecondary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? 'Active' : subTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall!.copyWith(
                        color: isActive ? ext.activeAccent : ext.textSecondary,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top-Right Floating Checkmark Badge
        if (isActive)
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ext.activeAccent,
                border: Border.all(
                  color: ext.surfaceContainerLow,
                  width: 2,
                ),
              ),
              child: const Icon(
                size: 14,
                LucideIcons.check,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}