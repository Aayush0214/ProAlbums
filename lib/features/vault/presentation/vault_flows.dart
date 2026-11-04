import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/presentation/providers/recently_deleted_setting.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_texts.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_auth_dialog.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// Settings > Hidden photos: the check when "Password for hidden photos" is
/// on (fingerprint / PIN card), straight in when it is off.
Future<void> openHiddenPhotos(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(vaultRepositoryProvider);
  final status = await ref.read(vaultSessionProvider.notifier).refresh();
  if (!context.mounted) return;
  if (status.passwordEnabled) {
    if (!await showVaultAuthDialog(context, ref)) return;
  } else if (status.created) {
    await repository.unlockWithoutPassword();
  }
  // No vault yet (nothing hidden): the page simply shows it is empty.
  if (context.mounted) await context.push<void>(AppRoutes.vault);
}

/// Makes the vault the first time (first Hide or first password): the
/// Recovery Key is shown once and must be confirmed. false = could not.
Future<bool> ensureVaultCreated(BuildContext context, WidgetRef ref) async {
  final toast = AppToast.of(context);
  final status = await ref.read(vaultSessionProvider.notifier).refresh();
  if (status.created) return true;
  final created = await ref.read(vaultRepositoryProvider).create();
  String? recoveryKey;
  created.match(
    (failure) => toast.show(failure.message),
    (key) => recoveryKey = key,
  );
  if (recoveryKey == null || !context.mounted) return false;
  final saved = await context.push<bool>(
    AppRoutes.vaultRecoveryKey,
    extra: recoveryKey,
  );
  return saved ?? false;
}

/// Settings > "Password for hidden photos" switch.
///  - On, first time: the vault is made if needed (Recovery Key), then the
///    PIN + security questions.
///  - On / off once a PIN exists: the check first.
Future<void> setVaultPassword(
  BuildContext context,
  WidgetRef ref, {
  required bool enabled,
}) async {
  final repository = ref.read(vaultRepositoryProvider);
  final session = ref.read(vaultSessionProvider.notifier);
  final toast = AppToast.of(context);
  try {
    final status = await session.refresh();
    if (!context.mounted) return;

    if (enabled && !status.hasPin) {
      if (!await ensureVaultCreated(context, ref) || !context.mounted) return;
      final set = await context.push<bool>(AppRoutes.vaultSetup);
      if (set ?? false) toast.show('Password for hidden photos is on');
      return;
    }

    // A PIN exists: prove it is you, then flip the switch.
    if (!await showVaultAuthDialog(context, ref)) return;
    final result = await repository.setPasswordEnabled(enabled: enabled);
    result.match(
      (failure) => toast.show(failure.message),
      (_) => toast.show(
        enabled
            ? 'Password for hidden photos is on'
            : 'Password for hidden photos is off',
      ),
    );
  } finally {
    // Nothing stays unlocked after a settings change.
    await repository.lock();
    await session.refresh();
  }
}

/// Hide (selection bar More, viewer More): the check when the password is
/// on; the Recovery Key once if the vault does not exist yet; then a
/// progress dialog while each item is encrypted, and Android's own request
/// to delete the originals. The vault is locked again at the end.
/// true = something was hidden (the selection then closes).
Future<bool> hideMediaItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return false;
  final repository = ref.read(vaultRepositoryProvider);
  final session = ref.read(vaultSessionProvider.notifier);
  final toast = AppToast.of(context);
  final status = await session.refresh();
  if (!context.mounted) return false;

  try {
    if (status.passwordEnabled) {
      if (!await showVaultAuthDialog(context, ref)) return false;
    } else {
      if (!await ensureVaultCreated(context, ref)) return false;
      final unlocked = await repository.unlockWithoutPassword();
      if (!unlocked.getOrElse((_) => false)) {
        toast.show('The private vault is not available right now.');
        return false;
      }
    }
    if (!context.mounted) return false;

    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<(int, int)>((0, items.length));
    final dialog = showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => _VaultProgressDialog(
        progress: progress,
        title: items.length == 1
            ? 'Hiding 1 item'
            : 'Hiding ${items.length} items',
        message: 'Encrypting into the private vault',
      ),
    );
    var dialogOpen = true;
    final result = await ref.read(hideMediaUseCaseProvider)(
      items,
      // Hearts go into the vault with the items (back on Unhide).
      favorites: ref.read(favoriteIdsProvider).value ?? const {},
      onProgress: (done, total) {
        progress.value = (done, total);
        // All encrypted: Android's delete request comes next.
        if (done == total && dialogOpen) {
          dialogOpen = false;
          navigator.pop();
        }
      },
    );
    if (dialogOpen) {
      dialogOpen = false;
      navigator.pop();
    }
    await dialog;
    progress.dispose();

    return result.match<bool>(
      (failure) {
        toast.show(failure.message);
        return false;
      },
      (hide) {
        if (hide.cancelled) {
          toast.show('Nothing was hidden');
          return false;
        }
        toast.show(_hideMessage(hide));
        ref.invalidate(hiddenCountProvider);
        // Hidden items left the gallery: drop their hearts too (when all
        // went in, so no heart of a still-visible item is lost).
        if (hide.failed == 0) {
          unawaited(
            ref.read(setFavoriteUseCaseProvider)([
              for (final item in items) item.id,
            ], value: false),
          );
        }
        return hide.hidden > 0;
      },
    );
  } finally {
    await repository.lock();
    await session.refresh();
  }
}

String _hideMessage(HideResult hide) {
  final hidden = hide.hidden == 1
      ? '1 item hidden'
      : '${hide.hidden} items hidden';
  if (hide.failed == 0) return hidden;
  return '$hidden, ${hide.failed} could not be hidden';
}

/// A title ("Hiding 3 items"...), a line under it and a bar while the vault
/// works through the items.
class _VaultProgressDialog extends StatelessWidget {
  const _VaultProgressDialog({
    required this.progress,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  final ValueNotifier<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (context, value, _) {
              final (done, total) = value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: context.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total == 0 ? null : done / total,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$done / $total',
                    textAlign: TextAlign.end,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Unhide (vault selection bar or viewer): "Unhide N items?" ("Unhide all
/// items?" when every hidden item is chosen), then each goes back to the
/// folder it was hidden from. true = done (the selection closes).
Future<bool> unhideHiddenItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return false;
  final toast = AppToast.of(context);
  final all = items.length == ref.read(vaultMediaItemsProvider).length;
  final confirmed = await showConfirmDialog(
    context,
    title: switch (items.length) {
      _ when all && items.length > 1 => 'Unhide all items?',
      1 => 'Unhide this ${items.first.isVideo ? 'video' : 'image'}?',
      final count => 'Unhide $count items?',
    },
    confirmLabel: 'Unhide',
    destructive: false,
  );
  if (confirmed != true || !context.mounted) return false;

  final result = await _withProgress(
    context,
    title: items.length == 1
        ? 'Unhiding 1 item'
        : 'Unhiding ${items.length} items',
    message: 'Putting them back in their albums',
    total: items.length,
    work: (onProgress) => ref.read(vaultRepositoryProvider).restore([
      for (final item in items) vaultFileId(item.id),
    ], onProgress: onProgress),
  );
  ref.invalidate(vaultEntriesProvider);
  ref.invalidate(hiddenCountProvider);
  return result.match(
    (failure) {
      toast.show(failure.message);
      return false;
    },
    (counts) {
      _giveHeartsBack(ref, counts);
      toast.show(
        _countMessage(counts, one: 'item unhidden', many: 'items unhidden'),
      );
      return counts.done > 0;
    },
  );
}

/// Delete (vault selection bar or viewer): the gallery's delete words
/// ("Delete all items?" when every hidden item is chosen). Recently deleted
/// on → decrypted back and straight into the trash (30 days, restorable);
/// off → the vault files are deleted for good.
Future<bool> deleteHiddenItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return false;
  final toast = AppToast.of(context);
  final toTrash = await ref.read(recentlyDeletedEnabledProvider.future);
  if (!context.mounted) return false;
  final all = items.length == ref.read(vaultMediaItemsProvider).length;
  final texts = deleteDialogTexts(items, toTrash: toTrash);
  final confirmed = await showConfirmDialog(
    context,
    title: all && items.length > 1 ? 'Delete all items?' : texts.title,
    message: texts.message,
    confirmLabel: texts.confirm,
  );
  if (confirmed != true || !context.mounted) return false;

  final repository = ref.read(vaultRepositoryProvider);
  final ids = [for (final item in items) vaultFileId(item.id)];
  final result = toTrash
      ? await _withProgress(
          context,
          title: items.length == 1
              ? 'Deleting 1 item'
              : 'Deleting ${items.length} items',
          message: 'Moving them to Recently deleted',
          total: items.length,
          work: (onProgress) =>
              repository.restore(ids, toTrash: true, onProgress: onProgress),
        )
      : await repository.deleteForGood(ids);
  ref.invalidate(vaultEntriesProvider);
  ref.invalidate(hiddenCountProvider);
  return result.match(
    (failure) {
      toast.show(failure.message);
      return false;
    },
    (counts) {
      // Into the trash with their heart: Restore there brings it back too.
      _giveHeartsBack(ref, counts);
      toast.show(
        toTrash
            ? _countMessage(
                counts,
                one: 'item moved to "Recently deleted"',
                many: 'items moved to "Recently deleted"',
              )
            : _countMessage(counts, one: 'item deleted', many: 'items deleted'),
      );
      return counts.done > 0;
    },
  );
}

/// Restored items that had a heart when hidden get it again (their gallery
/// id is new).
void _giveHeartsBack(WidgetRef ref, VaultCounts counts) {
  if (counts.favorites.isEmpty) return;
  unawaited(
    ref.read(setFavoriteUseCaseProvider)(counts.favorites, value: true),
  );
}

String _countMessage(
  VaultCounts counts, {
  required String one,
  required String many,
}) {
  final done = counts.done == 1 ? '1 $one' : '${counts.done} $many';
  return counts.failed == 0 ? done : '$done, ${counts.failed} failed';
}

/// Runs [work] behind a progress dialog that follows its progress.
Future<T> _withProgress<T>(
  BuildContext context, {
  required String title,
  required String message,
  required int total,
  required Future<T> Function(void Function(int done, int total)) work,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<(int, int)>((0, total));
  final dialog = showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => VaultSecureScope(
      child: _VaultProgressDialog(
        progress: progress,
        title: title,
        message: message,
      ),
    ),
  );
  try {
    return await work((done, all) => progress.value = (done, all));
  } finally {
    navigator.pop();
    await dialog;
    progress.dispose();
  }
}

/// Restore hidden items (vault page menu, or its empty state): after a
/// reinstall, or with a "ProAlbums Vault" folder copied from another phone.
/// Explained first; then the system folder picker, the Recovery Key, and —
/// if this install has no privacy password yet — a new one.
Future<void> restoreVaultFlow(BuildContext context, WidgetRef ref) async {
  final toast = AppToast.of(context);
  final start = await showConfirmDialog(
    context,
    title: 'Restore hidden items',
    message:
        'Bring back hidden photos and videos from before a reinstall, or '
        'from a "ProAlbums Vault" folder copied from another phone.\n\n'
        'Choose the "ProAlbums Vault" folder in Documents, then enter your '
        'Recovery Key.',
    confirmLabel: 'Choose folder',
    destructive: false,
  );
  if (start != true || !context.mounted) return;

  final picked = await ref.read(vaultRepositoryProvider).pickVaultFolder();
  if (!context.mounted) return;
  final found = picked.fold((failure) {
    toast.show(failure.message);
    return null;
  }, (found) => found);
  if (found == null) return;
  if (!found.hasKey) {
    toast.show('No vault found there. Choose Documents > ProAlbums Vault');
    return;
  }
  if (found.items == 0) {
    toast.show('No hidden items in that folder');
    return;
  }

  final restored = await context.push<bool>(
    AppRoutes.vaultRestore,
    extra: found.items,
  );
  ref.invalidate(vaultEntriesProvider);
  ref.invalidate(hiddenCountProvider);
  if (!(restored ?? false) || !context.mounted) return;

  // A new install has no privacy password yet: set one now.
  final status = await ref.read(vaultSessionProvider.notifier).refresh();
  if (!status.hasPin && context.mounted) {
    await context.push<bool>(AppRoutes.vaultSetup);
    await ref.read(vaultSessionProvider.notifier).refresh();
  }
}
