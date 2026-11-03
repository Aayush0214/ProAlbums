import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Copy keeps the original where it is; Move takes it out of its album.
enum TransferMethod { copy, move }

/// "Select a method to add": Copy / Move / Cancel, like the system gallery
/// (a card at the bottom of the screen). null = Cancel or tapped outside.
Future<TransferMethod?> showTransferMethodDialog(BuildContext context) {
  return showDialog<TransferMethod>(
    context: context,
    builder: (context) => const _TransferMethodDialog(),
  );
}

class _TransferMethodDialog extends StatelessWidget {
  const _TransferMethodDialog();

  @override
  Widget build(BuildContext context) {
    Widget option(String label, TransferMethod? value) => SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(value),
            child: Text(label),
          ),
        );

    // Colours and shape come from the app's dialogTheme.
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a method to add',
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            option('Copy', TransferMethod.copy),
            option('Move', TransferMethod.move),
            option('Cancel', null),
          ],
        ),
      ),
    );
  }
}

/// Copies / moves [items] into [target] behind a small blocking spinner.
/// Returns the result, or null when it failed (nothing could be done).
/// The albums list is refreshed either way.
Future<TransferResult?> runTransfer(
  BuildContext context,
  WidgetRef ref, {
  required List<MediaItem> items,
  required TransferTarget target,
  required TransferMethod method,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
  final result = await ref.read(transferToAlbumUseCaseProvider)(
    items,
    target,
    move: method == TransferMethod.move,
  );
  navigator.pop();
  ref.invalidate(albumSectionsProvider);
  return result.fold((failure) => null, (value) => value);
}

/// The message after a Copy / Move. null when the person cancelled Android's
/// permission dialog (nothing happened, nothing to say).
String? transferMessage({
  required TransferMethod method,
  required String albumName,
  required TransferResult? result,
}) {
  final move = method == TransferMethod.move;
  final verb = move ? 'move' : 'copy';
  if (result == null || (result.done == 0 && result.failed > 0)) {
    return 'Could not $verb the selected items to "$albumName".';
  }
  if (result.cancelled) return null;
  final done = result.done;
  final moved = move ? 'Moved' : 'Copied';
  final what = done == 1 ? '1 item' : '$done items';
  if (result.failed > 0) {
    return '$moved $what to "$albumName". '
        '${result.failed} could not be ${move ? 'moved' : 'copied'}.';
  }
  return '$moved $what to "$albumName".';
}
