import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/cleanup/domain/cleanup_rules.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_providers.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// Albums > Cleanup suggestions: one card per kind that found something
/// (Duplicate images, Similar images…: count, pictures, "Clean up now
/// (size)"); "No images" in the middle when nothing is left.
class CleanupPage extends ConsumerStatefulWidget {
  const CleanupPage({super.key});

  @override
  ConsumerState<CleanupPage> createState() => _CleanupPageState();
}

class _CleanupPageState extends ConsumerState<CleanupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cleanupScanProvider.notifier).ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cleanupScanProvider);
    final kinds = [
      for (final kind in CleanupKind.values)
        if (state.groupsOf(kind).isNotEmpty) kind,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Cleanup suggestions'),
      ),
      body: !state.ready
          ? _Scanning(done: state.done, total: state.total)
          : kinds.isEmpty
          ? const CleanupEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final kind in kinds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _KindCard(kind: kind, groups: state.groupsOf(kind)),
                  ),
              ],
            ),
    );
  }
}

/// The first scan: how far it is.
class _Scanning extends StatelessWidget {
  const _Scanning({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Looking for duplicate and similar pictures…',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: total == 0 ? null : done / total),
            if (total > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$done / $total',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "No images" in the middle (nothing to clean up).
class CleanupEmpty extends StatelessWidget {
  const CleanupEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.image,
            size: 64,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No images',
            style: context.textTheme.titleLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindCard extends ConsumerWidget {
  /// Pictures shown in a card.
  static const int _previewSlots = 4;

  const _KindCard({required this.kind, required this.groups});

  final CleanupKind kind;
  final List<CleanupGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = groups.fold<int>(0, (sum, group) => sum + group.length);
    final bytes = groups.fold<int>(
      0,
      (sum, group) => sum + group.fold<int>(0, (s, image) => s + image.size),
    );
    // A few pictures from the first sets.
    final preview = [
      for (final group in groups)
        for (final image in group) image,
    ].take(_previewSlots).toList();
    final load = thumbnailLoader(ref);

    return Material(
      color: context.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(kind.title, style: context.textTheme.titleMedium),
                const Spacer(),
                Text(
                  '$count',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 4 equal square slots across the card (fewer pictures leave
            // empty slots, so the size never changes).
            Row(
              children: [
                for (var i = 0; i < _previewSlots; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: i < preview.length
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image(
                                image: MediaThumbnailImage(
                                  id: preview[i].id,
                                  size: 256,
                                  load: load,
                                ),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => unawaited(
                  context.push<void>(AppRoutes.cleanupGroups, extra: kind),
                ),
                child: Text('Clean up now (${cleanupSize(bytes)})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deletes [images] the normal way (the app's delete dialog, Recently
/// deleted or for good per Settings) and takes them out of the sets at
/// once. true = deleted.
Future<bool> deleteCleanupImages(
  BuildContext context,
  WidgetRef ref,
  List<CleanupImage> images,
) async {
  final scan = ref.read(cleanupScanProvider.notifier);
  final done = await deleteMediaItems(context, ref, [
    for (final image in images) cleanupMediaItem(image),
  ]);
  if (done) scan.removeIds({for (final image in images) image.id});
  return done;
}
