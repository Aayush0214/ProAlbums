import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';
import 'package:proalbums/features/trash/presentation/providers/recently_deleted_setting.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_texts.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _askedAccessKey = 'asked_media_management';

/// The whole delete, from the button to the trash:
/// 1. our confirmation dialog,
/// 2. (only the first time) a short explanation + the Settings screen that
///    turns on "Media management", so later deletes need no Android dialog,
/// 3. move to the trash,
/// 4. a message.
///
/// [snackBarBottomInset]: the message floats this far above the screen's
/// bottom edge, so it can sit ABOVE a bottom bar (the viewer's) instead of
/// covering it.
///
/// Returns true when the items are in the trash. The grid and the viewer then
/// update by themselves (they listen to library changes).
Future<bool> deleteMediaItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items, {
  double snackBarBottomInset = 0,
}) async {
  if (items.isEmpty) return false;
  // Taken now: the screen can be gone (the viewer closes) when the message shows.
  final toast = AppToast.of(context);
  // Taken now too: "Undo" may be tapped after this screen is gone.
  final restore = ref.read(restoreFromTrashUseCaseProvider);

  // Settings > "Recently deleted": ON = trash (30 days), OFF = gone for good.
  final toTrash = await ref.read(recentlyDeletedEnabledProvider.future);
  if (!context.mounted) return false;

  final texts = deleteDialogTexts(items, toTrash: toTrash);
  final confirmed = await showConfirmDialog(
    context,
    title: texts.title,
    message: texts.message,
    confirmLabel: texts.confirm,
  );
  if (confirmed != true || !context.mounted) return false;

  final access = ref.read(mediaManagementAccessUseCaseProvider);
  if (!await access.isGranted() && context.mounted) {
    await _askForAccessOnce(context, access.request);
  }

  if (!toTrash) {
    return _deleteForGood(
      ref,
      items,
      toast: toast,
      bottomInset: snackBarBottomInset,
    );
  }

  final result = await ref.read(moveToTrashUseCaseProvider)(items);
  return result.match(
    (failure) {
      toast.show(
        'Could not delete the selected items.',
        bottomInset: snackBarBottomInset,
      );
      return false;
    },
    (outcome) {
      if (outcome != TrashOutcome.trashed) return false;
      toast.show(
        items.length == 1
            ? 'Moved to "Recently deleted".'
            : '${items.length} items moved to "Recently deleted".',
        bottomInset: snackBarBottomInset,
        // Undo = take them out of the trash again.
        actionLabel: 'Undo',
        onAction: () => unawaited(restore(items)),
      );
      return true;
    },
  );
}

/// "Recently deleted" is OFF: the items are removed from the phone. No Undo.
Future<bool> _deleteForGood(
  WidgetRef ref,
  List<MediaItem> items, {
  required AppToast toast,
  required double bottomInset,
}) async {
  final result = await ref.read(deleteForeverUseCaseProvider)(items);
  return result.match(
    (failure) {
      toast.show(
        'Could not delete the selected items.',
        bottomInset: bottomInset,
      );
      return false;
    },
    (outcome) {
      if (outcome != TrashActionOutcome.done) return false;
      toast.show(
        items.length == 1
            ? 'Deleted permanently.'
            : '${items.length} items deleted permanently.',
        bottomInset: bottomInset,
      );
      return true;
    },
  );
}

/// Asked ONE time in the life of the app. If the person says "Not now", the
/// delete still works (with Android's own dialog), and we do not ask again.
Future<void> _askForAccessOnce(
  BuildContext context,
  Future<bool> Function() request,
) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedAccessKey) ?? false) return;
    await prefs.setBool(_askedAccessKey, true);
  } on Object {
    return; // cannot remember: better not to ask than to ask every time
  }
  if (!context.mounted) return;

  final allow = await showConfirmDialog(
    context,
    title: 'Delete without extra pop-ups?',
    message:
        'Turn on "Media management" for ProAlbums on the next screen. '
        'Then deleting only asks once (in the app), not again in Android.',
    confirmLabel: 'Open settings',
    cancelLabel: 'Not now',
    destructive: false,
  );
  if (allow ?? false) await request();
}
