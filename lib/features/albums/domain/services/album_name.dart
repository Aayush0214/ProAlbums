/// Checks the name of a new album. It becomes a folder name, so it must be a
/// valid one. Returns an error text, or null when the name is fine.
String? validateAlbumName(String input, Iterable<String> existingNames) {
  final name = input.trim();
  if (name.isEmpty) return 'Enter a name';
  if (name.length > 50) return 'The name is too long';
  if (name.startsWith('.')) return 'The name cannot start with a dot';
  if (RegExp(r'[\\/:*?"<>|]').hasMatch(name)) {
    return 'The name cannot contain \\ / : * ? " < > |';
  }
  final lower = name.toLowerCase();
  for (final existing in existingNames) {
    if (existing.toLowerCase() == lower) return 'This album already exists';
  }
  return null;
}
