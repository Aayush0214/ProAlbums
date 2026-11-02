import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/providers/album_prefs_controller.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/new_album_dialog.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// The select-mode actions on whole albums. Each one returns true when it
/// did something, so the screen can leave select mode.

/// "All", "Videos" and "Favorites" are not folders: you cannot rename or
/// delete them.
bool isRealFolder(Album album) =>
    album.kind != AlbumKind.all &&
    album.kind != AlbumKind.videos &&
    album.kind != AlbumKind.favorites;

void _say(BuildContext context, String text) => showAppSnackBar(context, text);

Future<List<MediaItem>> _itemsOf(WidgetRef ref, List<Album> albums) async {
  final seen = <String>{};
  final items = <MediaItem>[];
  for (final album in albums) {
    final result = await ref.read(getAlbumItemsUseCaseProvider)(album.id);
    result.match((failure) {}, (list) {
      for (final item in list) {
        if (seen.add(item.id)) items.add(item);
      }
    });
  }
  return items;
}

Future<bool> shareAlbums(
  BuildContext context,
  WidgetRef ref,
  List<Album> albums,
) async {
  final items = await _itemsOf(ref, albums);
  if (items.isEmpty || !context.mounted) return false;
  final result = await ref.read(shareMediaUseCaseProvider)([
    for (final item in items) item.id,
  ]);
  return result.match(
    (failure) {
      if (context.mounted) _say(context, 'Could not share the selected albums.');
      return false;
    },
    (_) => true,
  );
}

Future<bool> deleteAlbums(
  BuildContext context,
  WidgetRef ref,
  List<Album> albums,
) async {
  final items = await _itemsOf(ref, albums);
  if (!context.mounted) return false;

  if (items.isNotEmpty) {
    // Pictures / videos inside: the normal delete (confirm, Android trash).
    final done = await deleteMediaItems(context, ref, items);
    if (!done) return false;
  } else {
    // Only empty albums (just folders): ask, then remove the folders.
    final yes = await _confirmEmptyDelete(context, albums.length);
    if (yes != true) return false;
  }

  // Every deleted album is forgotten as a folder this app made, and its
  // folder is removed when nothing is left in it. (Albums that had pictures
  // keep their hidden ".trashed" files in the folder, so Android removes
  // those later, but the album must not stay in our list as an empty one.)
  final folders = ref.read(albumFolderRepositoryProvider);
  for (final album in albums) {
    await folders.removeFolderIfEmpty(album.name);
  }
  ref.read(albumPrefsControllerProvider.notifier).forget([
    for (final album in albums) album.name,
  ]);
  ref.invalidate(albumSectionsProvider);
  return true;
}

Future<bool?> _confirmEmptyDelete(BuildContext context, int count) {
  return showConfirmDialog(
    context,
    title: count == 1 ? 'Delete this album?' : 'Delete $count albums?',
    message: 'These albums have no photos or videos in them.',
    confirmLabel: 'Delete',
  );
}

Future<bool> renameAlbum(
  BuildContext context,
  WidgetRef ref,
  Album album,
  Iterable<String> otherNames,
) async {
  final folders = ref.read(albumFolderRepositoryProvider);
  // Only the folders directly inside Pictures can be renamed: the others
  // (Camera, WhatsApp, Movies...) belong to the phone or another app.
  if (!await folders.isPicturesFolder(album.name)) {
    if (context.mounted) _say(context, 'This album cannot be renamed.');
    return false;
  }
  if (!context.mounted) return false;
  final name = await showNewAlbumDialog(
    context,
    existingNames: otherNames.where((n) => n != album.name),
    title: 'Rename album',
    initialName: album.name,
  );
  if (name == null || name == album.name || !context.mounted) return false;

  final items = await _itemsOf(ref, [album]);
  final bool renamed;
  var failed = 0;
  if (items.isEmpty) {
    // An empty album is only a folder: rename the folder itself. (No files
    // to move, so Android has nothing to ask permission for.)
    renamed = await folders.renameEmptyFolder(album.name, name);
  } else {
    final result = await ref.read(transferToAlbumUseCaseProvider)(
      items,
      name,
      move: true,
    );
    final value = result.fold((failure) => null, (value) => value);
    if (value == null) {
      if (context.mounted) _say(context, 'Could not rename the album.');
      return false;
    }
    if (value.cancelled) return false;
    failed = value.failed;
    renamed = failed == 0;
    if (renamed) await folders.removeFolderIfEmpty(album.name);
  }

  // Its place in "Other albums" and its cover must follow the new name.
  if (renamed) {
    ref.read(albumPrefsControllerProvider.notifier).renameAlbum(album.name, name);
  }
  ref.invalidate(albumSectionsProvider);
  // Android renames the album a moment AFTER the files moved, so look again
  // a little later (the first look can still show the old name).
  for (final wait in const [600, 1800]) {
    Future<void>.delayed(Duration(milliseconds: wait), () {
      try {
        ref.invalidate(albumSectionsProvider);
      } on Object {
        // The screen is gone; nothing to refresh.
      }
    });
  }
  if (context.mounted) {
    _say(
      context,
      renamed
          ? 'Renamed to "$name".'
          : (failed > 0
              ? '$failed items could not be moved to "$name".'
              : 'Could not rename the album.'),
    );
  }
  return renamed;
}

Future<bool> changeCover(
  BuildContext context,
  WidgetRef ref,
  Album album,
) async {
  final mediaId = await context.push<String>(AppRoutes.changeCover(album.id));
  if (mediaId == null) return false;
  ref.read(albumPrefsControllerProvider.notifier).setCover(album.name, mediaId);
  return true;
}
