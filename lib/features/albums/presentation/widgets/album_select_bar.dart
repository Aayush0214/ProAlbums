import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/providers/album_prefs_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/album_selection_controller.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_actions.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';

/// The bottom bar of the albums select mode, with the same rules as the
/// system gallery:
///  - Move to Others / Remove from Others: only real folders can go to Others
///  - Share: any selection
///  - Delete: real folders only (not "All" / "Videos")
///  - Rename and More > Change cover: exactly ONE album
class AlbumSelectBar extends ConsumerWidget {
  const AlbumSelectBar({
    required this.scope,
    required this.selected,
    required this.inOthers,
    required this.allNames,
    super.key,
  });

  /// 'albums' or 'other' (see AlbumSelection).
  final String scope;
  final List<Album> selected;

  /// true on the "Other albums" screen: the first button is then
  /// "Remove from Others".
  final bool inOthers;

  /// Every album name, to refuse a rename onto an existing name.
  final Iterable<String> allNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.read(albumSelectionProvider(scope).notifier);
    final prefs = ref.read(albumPrefsControllerProvider.notifier);
    final has = selected.isNotEmpty;
    final single = selected.length == 1;
    final names = [for (final a in selected) a.name];

    void leaveIf(bool done) {
      if (done) selection.exit();
    }

    return AlbumActionBar(
      actions: [
        AlbumBarAction(
          icon: LucideIcons.logOut,
          label: inOthers ? 'Remove from\nOthers' : 'Move to\nOthers',
          onPressed: !has ||
                  (!inOthers && !selected.every((a) => a.kind == AlbumKind.folder))
              ? null
              : () {
                  if (inOthers) {
                    prefs.removeFromOthers(names);
                  } else {
                    prefs.sendToOthers(names);
                  }
                  selection.exit();
                },
        ),
        AlbumBarAction(
          icon: LucideIcons.share2,
          label: 'Share',
          onPressed: !has
              ? null
              : () async => leaveIf(await shareAlbums(context, ref, selected)),
        ),
        AlbumBarAction(
          icon: LucideIcons.trash2,
          label: 'Delete',
          onPressed: !has || !selected.every(isRealFolder)
              ? null
              : () async => leaveIf(await deleteAlbums(context, ref, selected)),
        ),
        AlbumBarAction(
          icon: LucideIcons.pencil,
          label: 'Rename',
          onPressed: !single || selected.first.kind != AlbumKind.folder
              ? null
              : () async => leaveIf(
                    await renameAlbum(context, ref, selected.first, allNames),
                  ),
        ),
      ],
      moreLabel: 'Change cover',
      onMore: !single || selected.first.count == 0
          ? null
          : () async => leaveIf(await changeCover(context, ref, selected.first)),
    );
  }
}
