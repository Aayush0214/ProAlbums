import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/pages/other_albums_page.dart';
import 'package:proalbums/features/albums/presentation/providers/album_selection_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_select_bar.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_tile.dart';
import 'package:proalbums/features/albums/presentation/widgets/new_album_flow.dart';
import 'package:proalbums/features/albums/presentation/widgets/open_album.dart';
import 'package:proalbums/features/albums/presentation/widgets/other_albums_tile.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_card.dart';
import 'package:proalbums/features/trash/presentation/widgets/recently_deleted_row.dart';
import 'package:proalbums/shared/shell/shell_bottom_bar_provider.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

enum _AlbumsMenu { select, settings }

/// The Albums tab: the albums, "More albums" with "Other albums", New album
/// the select mode and "Recently deleted". Intelligent classification, Cleanup
/// and Internal storage are added in the next steps.
class AlbumsPage extends ConsumerWidget {
  const AlbumsPage({super.key});

  static const double _side = 16;
  static const double _gap = 12;
  static const String _scope = 'albums';
  static const String _owner = 'albums-selection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(albumSectionsProvider);
    final selection = ref.watch(albumSelectionProvider(_scope));
    final selectionController = ref.read(albumSelectionProvider(_scope).notifier);

    // Load "All" in the background while the person is on this tab, so the
    // "Select items" screen (New album) and the All album open at once.
    ref.listen(albumItemsProvider(kAllAlbumId), (previous, next) {});

    // The select bar takes the place of the navigation bar.
    ref.listen(albumSelectionProvider(_scope).select((s) => s.active), (
      previous,
      active,
    ) {
      final bar = ref.read(shellBottomBarHiddenProvider.notifier);
      if (active) {
        bar.hide(_owner);
      } else {
        bar.show(_owner);
      }
    });

    final actions = <Widget>[
      IconButton(
        tooltip: 'Search',
        icon: const Icon(LucideIcons.search),
        onPressed: () => showComingSoon(context, 'Search'),
      ),
      IconButton(
        tooltip: 'New album',
        icon: const Icon(LucideIcons.plus),
        onPressed: () => startNewAlbumFlow(context, ref),
      ),
      PopupMenuButton<_AlbumsMenu>(
        tooltip: 'More',
        onSelected: (item) {
          switch (item) {
            case _AlbumsMenu.select:
              selectionController.start();
            case _AlbumsMenu.settings:
              context.push(AppRoutes.settings);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _AlbumsMenu.select, child: Text('Select')),
          PopupMenuItem(value: _AlbumsMenu.settings, child: Text('Settings')),
        ],
      ),
    ];

    final data = sections.value;
    final selectable = data == null ? <Album>[] : [...data.top, ...data.more];
    final selected = [
      for (final album in selectable)
        if (selection.ids.contains(album.id)) album,
    ];

    final Widget header = selection.active
        ? AlbumSelectionHeader(
            selectedCount: selected.length,
subtitle: selected.isEmpty
            ? null
            : '${NumberFormat.decimalPattern().format(selected.fold(0, (sum, a) => sum + a.count))} images or videos in total',
            itemCount: selectable.length,
            onSelectAllToggle: () => selected.length == selectable.length
                ? selectionController.clear()
                : selectionController.selectAll([for (final a in selectable) a.id]),
            onClose: selectionController.exit,
          )
        : CollapsingSliverAppBar(title: 'Albums', actions: actions);

    return PopScope(
      // Back while selecting = leave select mode (not the app).
      canPop: !selection.active,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) selectionController.exit();
      },
      child: Scaffold(
        bottomNavigationBar: selection.active
            ? AlbumSelectBar(
                scope: _scope,
                selected: selected,
                inOthers: false,
                allNames: [
                  for (final a in [...selectable, ...?data?.other]) a.name,
                ],
              )
            : null,
        body: sections.when(
          // While reloading (a photo was added) the old albums stay on screen.
          skipLoadingOnRefresh: true,
          loading: () => _Grid(
            header: header,
            children: [for (var i = 0; i < 6; i++) const AlbumTileSkeleton()],
          ),
          error: (error, stackTrace) => CustomScrollView(
            slivers: [
              header,
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load the albums.',
                        style: context.textTheme.bodyLarge,
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(albumSectionsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (data) {
            Widget tile(Album album) => selection.active
                ? SelectableAlbumTile(
                    album: album,
                    selected: selection.ids.contains(album.id),
                    onTap: () => selectionController.toggle(album.id),
                  )
                : AlbumTile(
                    album: album,
                    onTap: () => openAlbum(context, album),
                    // Long press = start selecting with this album.
                    onLongPress: () {
                      HapticFeedback.selectionClick();
                      selectionController.startWith(album.id);
                    },
                  );

            return _Grid(
              header: header,
              footer: selection.active
                  ? null
                  : const Column(
                      children: [
                        RecentlyDeletedRow(),
                        SizedBox(height: 12),
                        StorageCard(),
                      ],
                    ),
              moreChildren: [
                for (final album in data.more) tile(album),
                if (data.other.isNotEmpty)
                  OtherAlbumsTile(
                    albums: data.other,
                    onTap: () {
                      if (selection.active) return;
                      Navigator.of(context, rootNavigator: true).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => const OtherAlbumsPage(),
                        ),
                      );
                    },
                  ),
              ],
              children: [for (final album in data.top) tile(album)],
            );
          },
        ),
      ),
    );
  }
}

/// The albums as 3 columns, with the "More albums" heading in between.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.header,
    required this.children,
    this.moreChildren = const [],
    this.footer,
  });

  /// Rows under the albums ("Recently deleted").
  final Widget? footer;

  final Widget header;
  final List<Widget> children;
  final List<Widget> moreChildren;

  @override
  Widget build(BuildContext context) {
    // The bottom bar floats over the body (see MainShellPage), so its height
    // is added here.
    final bottom = MediaQuery.paddingOf(context).bottom + 16;

    return CustomScrollView(
      slivers: [
        header,
        SliverPadding(
          // Space between the app bar and the first row of albums.
          padding: const EdgeInsets.fromLTRB(
            AlbumsPage._side,
            12,
            AlbumsPage._side,
            0,
          ),
          sliver: _AlbumSliver(children: children),
        ),
        if (moreChildren.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AlbumsPage._side,
              24,
              AlbumsPage._side,
              12,
            ),
            sliver: SliverToBoxAdapter(
              child: Text('More albums', style: context.textTheme.titleLarge),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AlbumsPage._side),
            sliver: _AlbumSliver(children: moreChildren),
          ),
        ],
        if (footer != null)
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverToBoxAdapter(child: footer),
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }
}

class _AlbumSliver extends StatelessWidget {
  const _AlbumSliver({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        final tile =
            (constraints.crossAxisExtent - AlbumsPage._gap * (columns - 1)) /
                columns;
        return SliverGrid(
          delegate: SliverChildListDelegate(children),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AlbumsPage._gap,
            mainAxisSpacing: 12,
            // The square picture + name + count under it.
            mainAxisExtent: tile + 6 + 40,
          ),
        );
      },
    );
  }
}
