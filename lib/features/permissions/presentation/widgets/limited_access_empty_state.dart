import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';

/// Shown instead of the (empty) grid when the person allowed only selected
/// photos and selected none. Explains it and offers the two ways out:
/// pick photos, or allow all.
class LimitedAccessEmptyState extends ConsumerWidget {
  const LimitedAccessEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          32,
          24,
          32,
          // The navigation bar floats over the body.
          MediaQuery.paddingOf(context).bottom + 96,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Icon(LucideIcons.image, size: 36, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No photos allowed yet',
                textAlign: TextAlign.center,
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'You allowed ProAlbums to see only selected photos, and none '
                'is selected. Choose the photos to show, or allow all.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  // Lists reload by themselves: manageLimitedAccess() bumps
                  // the library revision.
                  onPressed: ref.read(mediaPermissionProvider.notifier).manageLimitedAccess,
                  child: const Text('Select photos'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: ref.read(mediaPermissionProvider.notifier).openSettings,
                child: const Text('Allow all photos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
