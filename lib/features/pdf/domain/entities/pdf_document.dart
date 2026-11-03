import 'package:intl/intl.dart';

/// Rules of a PDF made from pictures (Convert PDF).
abstract final class PdfRules {
  /// At most this many pictures (pages) in one PDF, counting the ones already
  /// added.
  static const int maxPages = 99;

  /// Where saved PDFs go (inside the phone's shared storage).
  static const String folder = 'Documents/ProAlbums';

  /// The same folder as people see it in a file manager.
  static const String folderLabel = 'Phone storage/Documents/ProAlbums';

  /// The suggested file name (no ".pdf"): "PDF ProAlbums_20261103_131637".
  static String defaultName(DateTime now) =>
      'PDF ProAlbums_${DateFormat('yyyyMMdd_HHmmss').format(now)}';

  /// A name typed by the user, made safe for a file name: trimmed, no
  /// ".pdf" at the end (it is added when saving), no characters Android
  /// refuses in a file name. null when nothing is left.
  static String? cleanName(String typed) {
    var name = typed.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4).trim();
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name.isEmpty ? null : name;
  }
}

/// A PDF saved into [PdfRules.folder].
final class SavedPdf {
  const SavedPdf({required this.uri, required this.fileName});

  /// Its content:// address (to open it).
  final String uri;

  /// The name it got, with ".pdf" (Android adds " (1)" when the name is
  /// taken).
  final String fileName;
}

/// What "Crop & rotate" did to one page, in the editor's terms: first turn
/// the picture by [rotateDegrees] (clockwise), then mirror it ([flip]),
/// then cut out [crop] (pixels of the turned + mirrored picture; null = the
/// whole picture).
final class PdfPageEditSpec {
  const PdfPageEditSpec({this.rotateDegrees = 0, this.flip = false, this.crop});

  final double rotateDegrees;
  final bool flip;
  final ({int left, int top, int width, int height})? crop;

  bool get isEmpty => rotateDegrees % 360 == 0 && !flip && crop == null;
}

/// A page after "Crop & rotate": its new picture (a JPEG in the app's
/// temporary folder) and that picture's size. The gallery's picture is never
/// changed.
final class PdfPageEdit {
  const PdfPageEdit({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}
