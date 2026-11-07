import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/presentation/widgets/people_grid.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// The scope of the Featured pictures (viewer list, actions).
const String featuredScopeId = 'featured';

/// For You > Featured > More: the best picture of each day as big cards
/// with the date. Tap = the viewer. Select (icon or long press) → check
/// boxes, ⤢ (viewer) and Delete = the normal gallery delete (Recently
/// deleted when it is on).
class FeaturedPage extends ConsumerStatefulWidget {
  const FeaturedPage({super.key});

  @override
  ConsumerState<FeaturedPage> createState() => _FeaturedPageState();
}

class _FeaturedPageState extends ConsumerState<FeaturedPage> {
  /// null = not selecting.
  Set<String>? _selected;

  void _toggle(String id) => setState(() {
    final selected = {...?_selected};
    if (!selected.remove(id)) selected.add(id);
    _selected = selected;
  });

  Future<void> _delete() async {
    final chosen = _selected ?? const <String>{};
    final items = [
      for (final item in ref.read(featuredItemsProvider))
        if (chosen.contains(item.id)) item,
    ];
    if (await deleteMediaItems(context, ref, items) && mounted) {
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = ref.watch(memoryScanProvider.select((s) => s.featured));
    final selected = _selected;
    return MediaScope(
      id: featuredScopeId,
      mediaContext: MediaContext.library,
      items: featuredItemsProvider,
      child: PopScope(
        canPop: selected == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _selected = null);
        },
        child: Scaffold(
          bottomNavigationBar: selected == null
              ? null
              : PeopleActionBar(
                  actions: [
                    (
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      onPressed: selected.isEmpty ? null : _delete,
                      destructive: true,
                    ),
                  ],
                ),
          body: Builder(
            // Below the scope: the viewer opens on the Featured list.
            builder: (context) => CustomScrollView(
              slivers: [
                if (selected != null)
                  AlbumSelectionHeader(
                    selectedCount: selected.length,
                    itemCount: featured.length,
                    onSelectAllToggle: () => setState(
                      () => _selected = selected.length == featured.length
                          ? {}
                          : {for (final f in featured) f.id},
                    ),
                    onClose: () => setState(() => _selected = null),
                  )
                else
                  CollapsingSliverAppBar(
                    title: 'Featured',
                    leading: const AppBackButton(),
                    actions: [
                      if (featured.isNotEmpty)
                        IconButton(
                          tooltip: 'Select',
                          icon: const Icon(LucideIcons.squareCheck),
                          onPressed: () => setState(() => _selected = {}),
                        ),
                    ],
                  ),
                if (featured.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No featured photos yet',
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    sliver: SliverList.separated(
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 20),
                      itemBuilder: (context, i) {
                        final picture = featured[i];
                        void open() =>
                            openMediaViewer(context, ref, id: picture.id);
                        return FeaturedCard(
                          id: picture.id,
                          takenMs: picture.takenMs,
                          selected: selected?.contains(picture.id),
                          onTap: selected != null
                              ? () => _toggle(picture.id)
                              : open,
                          onLongPress: selected != null
                              ? null
                              : () => setState(() => _selected = {picture.id}),
                          onExpand: open,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
