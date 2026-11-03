import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/providers/album_selection_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_select_bar.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_tile.dart';
import 'package:proalbums/features/albums/presentation/widgets/open_album.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// The albums behind the "Other albums" tile. Tap opens an album; the check
/// icon starts the select mode (Remove from Others, Share, Delete, Rename,
/// More > Change cover).
class OtherAlbumsPage extends ConsumerWidget {
  const OtherAlbumsPage({super.key});

  static const double _side = 16;
  static const double _gap = 12;
  static const String _scope = 'other';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(albumSectionsProvider).value;
    final albums = sections?.other ?? const <Album>[];
    final selection = ref.watch(albumSelectionProvider(_scope));
    final controller = ref.read(albumSelectionProvider(_scope).notifier);
    final tile =
        (MediaQuery.sizeOf(context).width - _side * 2 - _gap * 2) / 3;

    // Everything was removed from Others: nothing left to show here.
    if (sections != null && albums.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
    }

    final selected = [
      for (final album in albums)
        if (selection.ids.contains(album.id)) album,
    ];

    final Widget header = selection.active
        ? AlbumSelectionHeader(
            selectedCount: selected.length,
subtitle: selected.isEmpty
            ? null
            : '${NumberFormat.decimalPattern().format(selected.fold(0, (sum, a) => sum + a.count))} images or videos in total',
            itemCount: albums.length,
            onSelectAllToggle: () => selected.length == albums.length
                ? controller.clear()
                : controller.selectAll([for (final a in albums) a.id]),
            onClose: controller.exit,
          )
        : CollapsingSliverAppBar(
            title: 'Other albums',
            leading: const AppBackButton(),
            actions: [
              IconButton(
                tooltip: 'Select',
                icon: const Icon(LucideIcons.squareCheck),
                onPressed: controller.start,
              ),
            ],
          );

    return PopScope(
      canPop: !selection.active,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) controller.exit();
      },
      child: Scaffold(
        bottomNavigationBar: selection.active
            ? AlbumSelectBar(
                scope: _scope,
                selected: selected,
                inOthers: true,
                allNames: [
                  if (sections != null)
                    for (final a in [
                      ...sections.top,
                      ...sections.more,
                      ...sections.other,
                    ])
                      a.name,
                ],
              )
            : null,
        body: CustomScrollView(
          slivers: [
            header,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_side, 12, _side, 0),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: _gap,
                  mainAxisSpacing: _gap,
                  mainAxisExtent: tile + 6 + 40,
                ),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return selection.active
                      ? SelectableAlbumTile(
                          album: album,
                          selected: selection.ids.contains(album.id),
                          onTap: () => controller.toggle(album.id),
                        )
                      : AlbumTile(
                          album: album,
                          onTap: () => openAlbum(context, album),
                          onLongPress: () {
                            HapticFeedback.selectionClick();
                            controller.startWith(album.id);
                          },
                        );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ),
          ],
        ),
      ),
    );
  }
}
