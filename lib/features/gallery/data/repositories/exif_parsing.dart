/// Small helpers to turn the text the EXIF reader gives ("179/100", "[167]",
/// "26") into numbers. Pure functions, so they can be tested.
final RegExp _number = RegExp(r'-?\d+(?:\.\d+)?(?:\s*/\s*-?\d+(?:\.\d+)?)?');

/// "179/100" -> 1.79, "26" -> 26, "[167]" -> 167, "0" -> 0. null if no number.
double? parseExifNumber(String? printable) {
  if (printable == null) return null;
  final match = _number.firstMatch(printable);
  if (match == null) return null;

  final text = match.group(0)!;
  if (text.contains('/')) {
    final parts = text.split('/');
    final top = double.tryParse(parts[0].trim());
    final bottom = double.tryParse(parts[1].trim());
    if (top == null || bottom == null || bottom == 0) return null;
    return top / bottom;
  }
  return double.tryParse(text);
}

/// "iQOO Z9 5G" + "iQOO" -> "iQOO Z9 5G, iQOO". Same word twice is shown once.
String? cameraNameOf({String? model, String? make}) {
  final parts = <String>[];
  for (final raw in [model, make]) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) continue;
    if (parts.any((p) => p.toLowerCase() == value.toLowerCase())) continue;
    parts.add(value);
  }
  return parts.isEmpty ? null : parts.join(', ');
}
