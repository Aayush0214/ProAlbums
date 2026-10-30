import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/presentation/providers/limited_access_banner_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';

/// Shown above the grid when the user allowed only SOME photos. It explains
/// why the library looks small and offers the two ways out.
class LimitedAccessBanner extends ConsumerWidget {
  const LimitedAccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final permission = ref.read(mediaPermissionProvider.notifier);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only some photos are shown',
                  style: text.titleSmall?.copyWith(color: scheme.onSecondaryContainer),
                ),
                const SizedBox(height: 2),
                Text(
                  'You allowed access to selected photos only.',
                  style: text.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await permission.manageLimitedAccess();
                        ref.invalidate(photosControllerProvider);
                      },
                      child: const Text('Select more'),
                    ),
                    TextButton(
                      onPressed: permission.openSettings,
                      child: const Text('Allow all'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            color: scheme.onSecondaryContainer,
            icon: const Icon(Icons.close, size: 20),
            onPressed: ref.read(limitedBannerDismissedProvider.notifier).dismiss,
          ),
        ],
      ),
    );
  }
}
