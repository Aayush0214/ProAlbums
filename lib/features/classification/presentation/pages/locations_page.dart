import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/people_grid.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// Intelligent classification > Location (like the system gallery): every
/// place as an album tile, 3 per row, most pictures first: the newest
/// picture, the name, the count. A tap opens its pictures. Select (tick or
/// long press) → Share (every picture of the places) / Delete (every
/// picture, the normal delete: Recently deleted when it is on; restored
/// pictures bring their place back by themselves).
class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  /// Names of the chosen places; null = not selecting.
  Set<String>? _selected;

  void _toggle(String name) => setState(() {
    final next = {...?_selected};
    if (!next.remove(name)) next.add(name);
    _selected = next;
  });

  void _exit() => setState(() => _selected = null);

  List<MediaItem> _itemsOf(List<PlaceAlbum> albums) => [
    for (final album in albums)
      for (final p in album.pictures)
        MediaItem(
          id: p.id,
          type: MediaType.image,
          createdAt: DateTime.fromMillisecondsSinceEpoch(p.takenMs),
          width: 0,
          height: 0,
        ),
  ];

  Future<void> _share(List<PlaceAlbum> chosen) async {
    final toast = AppToast.of(context);
    final result = await ref.read(shareMediaUseCaseProvider)([
      for (final item in _itemsOf(chosen)) item.id,
    ]);
    result.match(
      (failure) => toast.show('Could not share the selected items.'),
      (_) {},
    );
  }

  Future<void> _delete(List<PlaceAlbum> chosen) async {
    final done = await deleteMediaItems(context, ref, _itemsOf(chosen));
    if (done && mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(placeAlbumListProvider);
    final allowed = ref.watch(placeScanProvider.select((s) => s.allowed));
    final list = albums.value ?? const <PlaceAlbum>[];
    final selected = _selected;
    final chosen = selected == null
        ? const <PlaceAlbum>[]
        : [
            for (final a in list)
              if (selected.contains(a.name)) a,
          ];
    final pictures = chosen.fold<int>(0, (s, a) => s + a.pictures.length);

    final Widget header = selected != null
        ? AlbumSelectionHeader(
            selectedCount: chosen.length,
            itemCount: list.length,
            subtitle: chosen.isEmpty
                ? null
                : '$pictures images or videos in total',
            onSelectAllToggle: () => setState(
              () => _selected = chosen.length == list.length
                  ? <String>{}
                  : {for (final a in list) a.name},
            ),
            onClose: _exit,
          )
        : CollapsingSliverAppBar(
            title: 'Location',
            leading: const AppBackButton(),
            actions: [
              if (list.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: () => setState(() => _selected = <String>{}),
                ),
            ],
          );

    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        bottomNavigationBar: selected == null
            ? null
            : PeopleActionBar(
                actions: [
                  (
                    icon: LucideIcons.share2,
                    label: 'Share',
                    onPressed: chosen.isEmpty ? null : () => _share(chosen),
                    destructive: false,
                  ),
                  (
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    onPressed: chosen.isEmpty ? null : () => _delete(chosen),
                    destructive: true,
                  ),
                ],
              ),
        body: CustomScrollView(
          slivers: [
            header,
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      !allowed
                          ? 'Allow ProAlbums to read photo locations to see '
                                'your places.'
                          : albums.isLoading
                          ? 'Scanning…'
                          : 'No places yet',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              _PlaceGrid(
                albums: list,
                selected: selected,
                onTap: (album) => selected != null
                    ? _toggle(album.name)
                    : unawaited(
                        context.push<void>(AppRoutes.place(album.name)),
                      ),
                onLongPress: selected != null
                    ? null
                    : (album) {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = {album.name});
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceGrid extends StatelessWidget {
  const _PlaceGrid({
    required this.albums,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final List<PlaceAlbum> albums;
  final Set<String>? selected;
  final ValueChanged<PlaceAlbum> onTap;
  final ValueChanged<PlaceAlbum>? onLongPress;

  static const double _side = 16;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tile = (width - _side * 2 - _gap * 2) / 3;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_side, 12, _side, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: _gap,
          mainAxisSpacing: 16,
          // Picture + a name of up to 2 lines + the count.
          mainAxisExtent: tile + 6 + 62,
        ),
        delegate: SliverChildBuilderDelegate(childCount: albums.length, (
          context,
          index,
        ) {
          final album = albums[index];
          final cover = album.pictures.first;
          final checked = selected?.contains(album.name);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(album),
            onLongPress: onLongPress == null ? null : () => onLongPress!(album),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MediaThumbnail(
                          item: MediaItem(
                            id: cover.id,
                            type: MediaType.image,
                            createdAt: DateTime.fromMillisecondsSinceEpoch(
                              cover.takenMs,
                            ),
                            width: 0,
                            height: 0,
                          ),
                          size: 320,
                        ),
                      ),
                      if (checked != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: SelectionCheckbox(
                            state: checked
                                ? SelectionState.all
                                : SelectionState.none,
                            onPhoto: true,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium,
                ),
                Text(
                  NumberFormat.decimalPattern().format(album.pictures.length),
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
