import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/new_album_dialog.dart';
import 'package:proalbums/features/albums/presentation/widgets/transfer_flow.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Asks for a name and creates the folder `Pictures/<name>` (an empty album is
/// fine). Returns the new album's name, or null when cancelled / it failed
/// (then [say] has already told the person why).
Future<String?> createNewAlbum(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String text) say,
}) async {
  // Names that are taken: every album AND every folder in Pictures.
  final sections = ref.read(albumSectionsProvider).value;
  final taken = <String>{
    if (sections != null)
      for (final album in [
        ...sections.top,
        ...sections.more,
        ...sections.other,
      ])
        album.name,
    ...await ref.read(albumFolderRepositoryProvider).listFolderNames(),
  };
  if (!context.mounted) return null;

  final name = await showNewAlbumDialog(context, existingNames: taken);
  if (name == null || !context.mounted) return null;

  final created = await ref.read(createAlbumUseCaseProvider)(name);
  final outcome = created.fold((failure) => null, (value) => value);
  if (outcome == null) {
    say('Could not create the album.');
    return null;
  }
  if (outcome == CreateFolderOutcome.alreadyExists) {
    say('This album already exists.');
    return null;
  }
  // The new (empty) album shows up in the list right away.
  ref.invalidate(albumSectionsProvider);
  return name;
}

/// The whole "+ New album" journey:
///  1. name → the folder Pictures/<(name)> is created (an empty album is fine)
///  2. pick items (optional)
///  3. Copy / Move / Cancel
Future<void> startNewAlbumFlow(BuildContext context, WidgetRef ref) async {
  // Taken now: the screens change while the person goes through the steps.
  final toast = AppToast.of(context);
  void say(String text) => toast.show(text);

  final name = await createNewAlbum(context, ref, say: say);
  if (name == null || !context.mounted) return;

  final picked = await context.push<List<MediaItem>>(AppRoutes.pickItems);
  if (!context.mounted) return;
  if (picked == null || picked.isEmpty) {
    say('Album "$name" created.');
    return;
  }

  final method = await showTransferMethodDialog(context);
  if (method == null || !context.mounted) {
    say('Album "$name" created.');
    return;
  }

  final result = await runTransfer(
    context,
    ref,
    items: picked,
    target: TransferTarget.newFolder(name),
    method: method,
  );
  say(
    transferMessage(method: method, albumName: name, result: result) ??
        'Album "$name" created.',
  );
}
