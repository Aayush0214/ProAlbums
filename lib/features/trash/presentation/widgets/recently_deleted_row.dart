import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/trash/presentation/providers/recently_deleted_setting.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/shared/widgets/bounce_tap.dart';

/// The "Recently deleted" card at the bottom of the Albums tab (with how many
/// items are in the trash). A raised card with a red icon that bounces when
/// pressed. Hidden when Settings > "Recently deleted" is off.
class RecentlyDeletedRow extends ConsumerWidget {
  const RecentlyDeletedRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      recentlyDeletedEnabledProvider.select((value) => value.value ?? true),
    );
    if (!enabled) return const SizedBox.shrink();

    final count = ref.watch(
      trashedItemsProvider.select((value) => value.value?.length ?? 0),
    );
    final scheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BounceTap(
        onTap: () => unawaited(context.push<void>(AppRoutes.recentlyDeleted)),
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
                    color: scheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(LucideIcons.trash2, size: 20, color: scheme.error),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Recently deleted',
                    style: context.textTheme.titleMedium,
                  ),
                ),
                if (count > 0)
                  Text(
                    NumberFormat.decimalPattern().format(count),
                    style: context.textTheme.bodyMedium
                        ?.copyWith(color: context.colors.textSecondary),
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
