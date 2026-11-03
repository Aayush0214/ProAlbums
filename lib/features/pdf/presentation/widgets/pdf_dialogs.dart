import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';

/// "Save to": where the PDF goes and its name (filled with [suggestedName],
/// all selected so typing replaces it). Returns the clean name, or null
/// (Cancel).
Future<String?> showSavePdfDialog(
  BuildContext context, {
  required String suggestedName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SavePdfDialog(suggestedName: suggestedName),
  );
}

class _SavePdfDialog extends StatefulWidget {
  const _SavePdfDialog({required this.suggestedName});

  final String suggestedName;

  @override
  State<_SavePdfDialog> createState() => _SavePdfDialogState();
}

class _SavePdfDialogState extends State<_SavePdfDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.suggestedName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.suggestedName.length,
        );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = PdfRules.cleanName(_name.text);
    if (name != null) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save to',
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              PdfRules.folderLabel,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (context, value, _) => TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  suffixText: '.pdf',
                  errorText: PdfRules.cleanName(value.text) == null
                      ? 'Enter a name'
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: PdfRules.cleanName(value.text) == null
                          ? null
                          : _save,
                      child: const Text('Save'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [title] ("Generating PDF", "Preparing to print") with an optional
/// [message] and a bar while the pictures are read ([progress] = done /
/// total). Cannot be closed by the user; the caller pops it.
Future<void> showPdfProgressDialog(
  BuildContext context,
  ValueNotifier<(int, int)> progress, {
  String title = 'Generating PDF',
  String? message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (context, value, _) {
              final (done, total) = value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: context.textTheme.titleMedium),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
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
    ),
  );
}
