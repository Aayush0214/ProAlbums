import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_edit_repository.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/details_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Viewer > More > Rename: the dialog starts with the current name (without
/// its extension, which is kept). A name another file in the folder already
/// has is reported in the dialog, which stays open. Files of other apps:
/// Android asks first. Returns true when renamed.
Future<bool> renameMediaItem(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final repository = ref.read(mediaEditRepositoryProvider);
  final toast = AppToast.of(context);
  final fileName = await repository.fileName(item);
  if (!context.mounted) return false;
  if (fileName == null) {
    toast.show('Could not rename this item');
    return false;
  }
  final renamed = await showDialog<bool>(
    context: context,
    builder: (context) => _RenameDialog(
      initialName: baseNameOf(fileName),
      onSubmit: (name) async {
        final outcome = await repository.rename(item, name);
        return switch (outcome) {
          MediaEditOutcome.done => null,
          MediaEditOutcome.nameTaken => 'This name is already used here',
          MediaEditOutcome.cancelled => '',
          MediaEditOutcome.unsupported ||
          MediaEditOutcome.failed => 'Could not rename this item',
        };
      },
    ),
  );
  if (renamed ?? false) {
    // The Info card shows the name.
    ref.invalidate(mediaDetailsProvider(item.id));
    return true;
  }
  return false;
}

/// Viewer > More > Rotate: the picture itself turns 90° clockwise, no
/// dialog (like the system gallery).
Future<bool> rotateMediaItem(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final toast = AppToast.of(context);
  final outcome = await ref.read(mediaEditRepositoryProvider).rotate(item);
  switch (outcome) {
    case MediaEditOutcome.done:
      // Same id, new picture: every grid, the viewer and the strip load it
      // again.
      MediaThumbnailImage.markChanged(item.id);
      ref
        ..invalidate(mediaDetailsProvider(item.id))
        ..invalidate(mediaHistogramProvider(item.id));
      return true;
    case MediaEditOutcome.unsupported:
      toast.show('This picture cannot be rotated');
    case MediaEditOutcome.cancelled:
      break;
    case MediaEditOutcome.nameTaken || MediaEditOutcome.failed:
      toast.show('Could not rotate this picture');
  }
  return false;
}

/// Viewer > More > Google Lens.
Future<void> openGoogleLens(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final toast = AppToast.of(context);
  if (!await ref.read(mediaEditRepositoryProvider).openGoogleLens(item)) {
    toast.show('Google Lens is not available on this phone');
  }
}

/// Viewer > More > Contact profile picture: the Contacts app does the rest
/// (choose the contact, crop).
Future<void> setAsContactPhoto(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final toast = AppToast.of(context);
  if (!await ref.read(mediaEditRepositoryProvider).setAsContactPhoto(item)) {
    toast.show('No app here can set a contact photo');
  }
}

/// Viewer > Edit: the phone's own editor; what it saves shows up in the
/// gallery by itself (the library notices the new file).
Future<void> openInEditor(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final toast = AppToast.of(context);
  if (!await ref.read(mediaEditRepositoryProvider).openEditor(item)) {
    toast.show(
      item.isVideo
          ? 'No video editor on this phone'
          : 'No photo editor on this phone',
    );
  }
}

/// "Rename": bold title, the name in a field with an X that empties it,
/// then Cancel / OK.
///
/// [onSubmit] does the rename: null = done (the dialog closes with true),
/// '' = cancelled by the person in Android's dialog (closes with false),
/// otherwise the message to show under the field (stays open).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName, required this.onSubmit});

  final String initialName;
  final Future<String?> Function(String name) onSubmit;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final problem = renameProblem(name);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (name == widget.initialName) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _busy = true);
    final answer = await widget.onSubmit(name);
    if (!mounted) return;
    if (answer == null || answer.isEmpty) {
      Navigator.of(context).pop(answer == null);
      return;
    }
    setState(() {
      _busy = false;
      _error = answer;
    });
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
              'Rename',
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (context, value, _) => TextField(
                controller: _name,
                autofocus: true,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  errorText: _error,
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () {
                            _name.clear();
                            setState(() => _error = null);
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
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
                      onPressed: _busy || value.text.trim().isEmpty
                          ? null
                          : _submit,
                      child: const Text('OK'),
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
