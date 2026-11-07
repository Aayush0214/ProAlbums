import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';
import 'package:proalbums/features/collage/presentation/collage_flow.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/presentation/memory_flows.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/memories/presentation/pages/featured_page.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// The For You tab (like the system gallery's "Recommended"): 🔍 and ⋮
/// (Settings), the Collage tile, then Memories (a big card + a row of
/// smaller ones, "More >") and Featured (a row of big cards, "More >").
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  /// Small memory cards after the big one.
  static const int _rowMemories = 10;

  /// Featured cards in the row.
  static const int _rowFeatured = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryListProvider).value ?? const [];
    final featured = ref.watch(memoryScanProvider.select((s) => s.featured));
    final ready = ref.watch(memoryScanProvider.select((s) => s.ready));
    final width = MediaQuery.sizeOf(context).width;

    return MediaScope(
      id: featuredScopeId,
      mediaContext: MediaContext.library,
      items: featuredItemsProvider,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            CollapsingSliverAppBar(
              title: 'For You',
              actions: [
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(LucideIcons.search),
                  onPressed: () => context.go(AppRoutes.search),
                ),
                PopupMenuButton<void>(
                  tooltip: 'More',
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      onTap: () =>
                          unawaited(context.push<void>(AppRoutes.settings)),
                      child: const Text('Settings'),
                    ),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: (width - 32 - 24) / 3,
                      child: _ToolTile(
                        icon: LucideIcons.layoutDashboard,
                        label: 'Collage',
                        onTap: () => unawaited(_collage(context, ref)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (memories.isNotEmpty) ...[
              _SectionTitle(
                title: 'Memories',
                onMore: () => unawaited(context.push<void>(AppRoutes.memories)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: MemoryCard(
                    memory: memories.first,
                    big: true,
                    onTap: () => openMemory(context, memories.first),
                    onMenu: (action) =>
                        _onMemoryMenu(context, ref, memories.first, action),
                  ),
                ),
              ),
              if (memories.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: (width - 32 - 16) / 2.15 + 12,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      itemCount: (memories.length - 1).clamp(0, _rowMemories),
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        final memory = memories[i + 1];
                        return MemoryCard(
                          memory: memory,
                          onTap: () => openMemory(context, memory),
                        );
                      },
                    ),
                  ),
                ),
            ] else if (ready)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Memories appear here as you take more photos',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            if (featured.isNotEmpty) ...[
              _SectionTitle(
                title: 'Featured',
                onMore: () => unawaited(context.push<void>(AppRoutes.featured)),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: width - 32 - 24,
                  child: Builder(
                    // Below the scope: the viewer opens on the Featured list.
                    builder: (context) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: featured.length.clamp(0, _rowFeatured),
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => FeaturedCard(
                        id: featured[i].id,
                        takenMs: featured[i].takenMs,
                        onTap: () => unawaited(
                          openMediaViewer(context, ref, id: featured[i].id),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // The bottom bar floats over the body (see MainShellPage).
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collage tile: pick 2–9 pictures, then the Collage page.
  Future<void> _collage(BuildContext context, WidgetRef ref) async {
    final toast = AppToast.of(context);
    final picked = await context.push<List<MediaItem>>(
      AppRoutes.pickItemsWith(max: CollageRules.maxPictures, imagesOnly: true),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    if (picked.length < CollageRules.minPictures) {
      toast.show('Select at least ${CollageRules.minPictures} pictures');
      return;
    }
    await makeCollage(context, ref, picked);
  }

  void _onMemoryMenu(
    BuildContext context,
    WidgetRef ref,
    StoredMemory memory,
    MemoryMenuAction action,
  ) {
    switch (action) {
      case MemoryMenuAction.viewGallery:
        viewMemoryGallery(context, memory);
      case MemoryMenuAction.rename:
        unawaited(renameMemory(context, ref, memory));
      case MemoryMenuAction.delete:
        unawaited(deleteMemories(context, ref, [memory.id]));
    }
  }
}

/// A section title with "More >".
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onMore});

  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.textTheme.titleLarge)),
          TextButton(
            onPressed: onMore,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('More'),
                SizedBox(width: 2),
                Icon(LucideIcons.chevronRight, size: 18),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A tool tile at the top (Collage): icon over the name on a rounded card.
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      // Low (Aayush: the square tile was too tall): icon over the name.
      child: SizedBox(
        height: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: context.colorScheme.primary),
            const SizedBox(height: 6),
            Text(label, style: context.textTheme.titleSmall),
          ],
        ),
      ),
    ),
  );
}
