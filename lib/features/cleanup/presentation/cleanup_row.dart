import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_providers.dart';
import 'package:proalbums/shared/widgets/bounce_tap.dart';

/// "Cleanup suggestions  208 >" on the Albums tab. Starts the scan the first
/// time it is shown; says "Scanning…" until the first scan is done. Hidden
/// when Settings > "Cleanup suggestions" is off.
class CleanupRow extends ConsumerStatefulWidget {
  const CleanupRow({super.key});

  @override
  ConsumerState<CleanupRow> createState() => _CleanupRowState();
}

class _CleanupRowState extends ConsumerState<CleanupRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cleanupScanProvider.notifier).ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      cleanupEnabledProvider.select((value) => value.value ?? true),
    );
    if (!enabled) return const SizedBox.shrink();
    final view = ref.watch(
      cleanupScanProvider.select((s) => (ready: s.ready, count: s.count)),
    );
    final scheme = context.colorScheme;
    final secondary = context.textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: BounceTap(
        onTap: () => unawaited(context.push<void>(AppRoutes.cleanup)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.cleanupCoralRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      LucideIcons.brushCleaning,
                      size: 20,
                      color: AppColors.cleanupCoralRed,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Cleanup suggestions',
                    style: context.textTheme.titleMedium,
                  ),
                ),
                if (!view.ready)
                  Text('Scanning…', style: secondary)
                else if (view.count > 0)
                  Text(
                    NumberFormat.decimalPattern().format(view.count),
                    style: secondary,
                  ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings > "Cleanup suggestions".
class CleanupSettingTile extends ConsumerWidget {
  const CleanupSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      cleanupEnabledProvider.select((value) => value.value ?? true),
    );
    return SwitchListTile(
      title: const Text('Cleanup suggestions'),
      subtitle: Text(
        'Finds duplicate and similar pictures to free up space.',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      value: enabled,
      onChanged: (on) =>
          ref.read(cleanupEnabledProvider.notifier).save(enabled: on),
    );
  }
}
