import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/presentation/pages/album_picker_page.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/new_album_dialog.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

enum _AddChoice { copy, move }

/// The whole "+ New album" journey:
///  1. name → the folder Pictures/<(name)> is created (an empty album is fine)
///  2. pick items (optional)
///  3. Copy / Move / Cancel
Future<void> startNewAlbumFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

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
  if (!context.mounted) return;

  final name = await showNewAlbumDialog(context, existingNames: taken);
  if (name == null || !context.mounted) return;

  final created = await ref.read(createAlbumUseCaseProvider)(name);
  if (!context.mounted) return;
  final outcome = created.fold((failure) => null, (value) => value);
  if (outcome == null) {
    say('Could not create the album.');
    return;
  }
  if (outcome == CreateFolderOutcome.alreadyExists) {
    say('This album already exists.');
    return;
  }
  // The new (empty) album shows up in the list right away.
  ref.invalidate(albumSectionsProvider);

  final picked = await Navigator.of(context, rootNavigator: true)
      .push<List<MediaItem>>(
    MaterialPageRoute<List<MediaItem>>(
      builder: (context) => const AlbumPickerPage(),
    ),
  );
  if (!context.mounted) return;
  if (picked == null || picked.isEmpty) {
    say('Album "$name" created.');
    return;
  }

  final choice = await showDialog<_AddChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add ${picked.length} '
          '${picked.length == 1 ? 'item' : 'items'} to "$name"'),
      content: const Text(
        'Copy keeps the originals where they are. '
        'Move takes them out of their current album.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_AddChoice.copy),
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_AddChoice.move),
          child: const Text('Move'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) {
    say('Album "$name" created.');
    return;
  }

  // A small blocking spinner while the files are copied / moved.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
  final result = await ref.read(transferToAlbumUseCaseProvider)(
    picked,
    name,
    move: choice == _AddChoice.move,
  );
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  ref.invalidate(albumSectionsProvider);
  final verb = choice == _AddChoice.move ? 'Moved' : 'Copied';
  result.fold(
    (failure) => say('Could not add the selected items.'),
    (value) {
      if (value.cancelled) {
        say('Album "$name" created. Nothing was ${verb.toLowerCase()}.');
      } else if (value.failed > 0) {
        say('$verb ${value.done}, ${value.failed} could not be '
            '${verb.toLowerCase()}.');
      } else {
        say('$verb ${value.done} to "$name".');
      }
    },
  );
}
