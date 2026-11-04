import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_auth_dialog.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

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
      builder: (context) => _HideProgressDialog(progress: progress),
    );
    var dialogOpen = true;
    final result = await ref.read(hideMediaUseCaseProvider)(
      items,
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

/// "Hiding N items" with a bar, while each item is encrypted.
class _HideProgressDialog extends StatelessWidget {
  const _HideProgressDialog({required this.progress});

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
                  Text(
                    total == 1 ? 'Hiding 1 item' : 'Hiding $total items',
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Encrypting into the private vault',
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
