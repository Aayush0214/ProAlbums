import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';

/// "Compress size" for a video (like the system gallery): the current
/// resolution and size, then one line per resolution with about how big the
/// copy gets (a check on the chosen one), Compress / Cancel.
Future<VideoCompressOption?> showVideoCompressDialog(
  BuildContext context, {
  required MediaCompressInfo info,
  required List<VideoCompressOption> options,
}) {
  return showDialog<VideoCompressOption>(
    context: context,
    builder: (context) => _VideoCompressDialog(info: info, options: options),
  );
}

class _VideoCompressDialog extends StatefulWidget {
  const _VideoCompressDialog({required this.info, required this.options});

  final MediaCompressInfo info;
  final List<VideoCompressOption> options;

  @override
  State<_VideoCompressDialog> createState() => _VideoCompressDialogState();
}

class _VideoCompressDialogState extends State<_VideoCompressDialog> {
  late VideoCompressOption _chosen = widget.options.first;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final primary = context.colorScheme.primary;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compress size',
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Current image quality: ${info.width} × ${info.height} '
                '(${formatMegabytes(info.sizeBytes)})',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (index, option) in widget.options.indexed) ...[
                      if (index > 0)
                        const Divider(height: 1, indent: 24, endIndent: 24),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        title: Text(
                          '${option.width}x${option.height} '
                          '(around ${formatMegabytes(option.estimatedBytes)})',
                          style: option == _chosen
                              ? TextStyle(color: primary)
                              : null,
                        ),
                        trailing: option == _chosen
                            ? Icon(LucideIcons.check, color: primary)
                            : null,
                        onTap: () => setState(() => _chosen = option),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: () => Navigator.of(context).pop(_chosen),
                  child: const Text('Compress'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
