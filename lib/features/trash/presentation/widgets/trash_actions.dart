import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// "Restore": [items] go back to their albums. true when done (Android may
/// ask first; "no" = false).
Future<bool> restoreMediaItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final width = MediaQuery.sizeOf(context).width;
  final result = await ref.read(restoreFromTrashUseCaseProvider)(items);
  return result.match(
    (failure) {
      showAppSnackBarOn(messenger, width, failure.message);
      return false;
    },
    (outcome) {
      if (outcome != TrashActionOutcome.done) return false;
      showAppSnackBarOn(
        messenger,
        width,
        items.length == 1 ? 'Restored.' : '${items.length} items restored.',
      );
      ref.invalidate(trashedItemsProvider);
      return true;
    },
  );
}

/// "Delete" in Recently deleted: asks, then removes [items] for good.
/// true when done.
Future<bool> deleteForeverMediaItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  final yes = await showConfirmDialog(
    context,
    title: items.length == 1
        ? 'Delete permanently?'
        : 'Delete ${items.length} items permanently?',
    message: 'This cannot be undone. The files will be removed from your phone.',
    confirmLabel: 'Delete',
  );
  if (yes != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final width = MediaQuery.sizeOf(context).width;
  final result = await ref.read(deleteForeverUseCaseProvider)(items);
  return result.match(
    (failure) {
      showAppSnackBarOn(messenger, width, failure.message);
      return false;
    },
    (outcome) {
      if (outcome != TrashActionOutcome.done) return false;
      showAppSnackBarOn(
        messenger,
        width,
        items.length == 1
            ? 'Deleted permanently.'
            : '${items.length} items deleted permanently.',
      );
      ref.invalidate(trashedItemsProvider);
      return true;
    },
  );
}
