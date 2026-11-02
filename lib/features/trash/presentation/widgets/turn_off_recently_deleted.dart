import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';
import 'package:proalbums/features/trash/presentation/providers/recently_deleted_setting.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// The switch in Settings was turned OFF: ask first, then delete everything
/// that is in "Recently deleted" for good, then save the choice.
///
/// Returns true when the setting is now off. If the person says Cancel (here
/// or in Android's own delete dialog) nothing changes and the switch stays on.
Future<bool> turnOffRecentlyDeleted(BuildContext context, WidgetRef ref) async {
  // Taken now: this screen may be gone when the work is finished.
  final messenger = ScaffoldMessenger.of(context);
  final width = MediaQuery.sizeOf(context).width;
  final container = ProviderScope.containerOf(context);
  final setting = ref.read(recentlyDeletedEnabledProvider.notifier);
  final listTrash = ref.read(getTrashedItemsUseCaseProvider);
  final deleteForever = ref.read(deleteForeverUseCaseProvider);

  final yes = await showConfirmDialog(
    context,
    title: 'Turn off "Recently deleted"?',
    message: 'Once turned off, images and videos in "Recently deleted" will '
        'be permanently deleted. Images and videos that are deleted later '
        'cannot be recovered.',
    confirmLabel: 'Turn off',
  );
  if (yes != true) return false;

  final listed = await listTrash();
  final trashed = listed.fold<List<TrashedItem>?>((_) => null, (items) => items);
  if (trashed == null) {
    showAppSnackBarOn(messenger, width, 'Could not turn off. Try again.');
    return false;
  }

  if (trashed.isNotEmpty) {
    final deleted = await deleteForever([
      for (final t in trashed) t.item,
    ]);
    final done = deleted.fold<bool?>(
      (_) => null,
      (outcome) => outcome == TrashActionOutcome.done,
    );
    if (done == null) {
      showAppSnackBarOn(messenger, width, 'Could not delete the items.');
      return false;
    }
    // Android's dialog was cancelled: keep everything as it was.
    if (!done) return false;
    container.invalidate(trashedItemsProvider);
  }

  await setting.save(enabled: false);
  return true;
}
