import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/storage/domain/services/format_bytes.dart';
import 'package:proalbums/features/storage/presentation/providers/storage_providers.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_bar.dart';
import 'package:proalbums/shared/widgets/bounce_tap.dart';

/// "Internal storage" at the bottom of the Albums tab: "47.0 GB used of
/// 107 GB" and one colour bar. Tap = the full "Storage analysis" screen.
class StorageCard extends ConsumerWidget {
  const StorageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep showing the old numbers while new ones load (no flicker).
    final usage = ref.watch(storageUsageProvider).value;
    if (usage == null || usage.total <= 0) return const SizedBox.shrink();

    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BounceTap(
        onTap: () => unawaited(context.push<void>(AppRoutes.storage)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Internal storage',
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          // Takes the space that is left; cut with "..." on a
                          // small screen / big font instead of overflowing.
                          Expanded(
                            child: Text(
                              '${formatBytes(usage.free)} free of '
                              '${formatBytes(usage.total)}',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StorageBar(usage: usage),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
