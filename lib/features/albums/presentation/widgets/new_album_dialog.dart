import 'package:flutter/material.dart';
import 'package:proalbums/features/albums/domain/services/album_name.dart';

/// Asks for the name of a new album. Returns the name, or null on Cancel.
Future<String?> showNewAlbumDialog(
  BuildContext context, {
  required Iterable<String> existingNames,
  String title = 'New album',
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NewAlbumDialog(
      existingNames: existingNames,
      title: title,
      initialName: initialName,
    ),
  );
}

class _NewAlbumDialog extends StatefulWidget {
  const _NewAlbumDialog({
    required this.existingNames,
    required this.title,
    required this.initialName,
  });

  final Iterable<String> existingNames;
  final String title;
  final String initialName;

  @override
  State<_NewAlbumDialog> createState() => _NewAlbumDialogState();
}

class _NewAlbumDialogState extends State<_NewAlbumDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validateAlbumName(_controller.text, widget.existingNames);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Colors, shape and buttons come from the app's dialogTheme.
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        maxLength: 50,
        decoration: InputDecoration(
          hintText: 'Album name',
          errorText: _error,
          counterText: '',
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
