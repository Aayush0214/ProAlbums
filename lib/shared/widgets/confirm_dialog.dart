import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// The app's confirmation dialog: title, message, a big action button and a
/// Cancel button. Colours, shape, text styles and the maximum width (400)
/// come from the app theme (dialogTheme).
///
/// Returns true when the action button was pressed. [destructive] paints the
/// button with the theme's error colour (delete, turn off ...). [cancelLabel]
/// is the text of the second button ("Not now" ...).
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: context.colorScheme.error,
                        foregroundColor: context.colorScheme.onError,
                        shape: const StadiumBorder(),
                      )
                    : FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
