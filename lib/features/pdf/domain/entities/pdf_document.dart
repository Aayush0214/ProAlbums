import 'package:intl/intl.dart';

/// Rules of a PDF made from pictures (Convert PDF).
abstract final class PdfRules {
  /// At most this many pictures (pages) in one PDF, counting the ones already
  /// added.
  static const int maxPages = 99;

  /// At most this many pictures in one print job. Android has no limit of
  /// its own; all pictures are kept in memory while the pages are made, and
  /// a huge job can stall the print screen or the printer.
  static const int maxPrintPictures = 99;

  /// Where saved PDFs go (inside the phone's shared storage).
  static const String folder = 'Documents/ProAlbums';

  /// The same folder as people see it in a file manager.
  static const String folderLabel = 'Phone storage/Documents/ProAlbums';

  /// The suggested file name (no ".pdf"): "PDF ProAlbums_20261103_131637".
  static String defaultName(DateTime now) =>
      'PDF ProAlbums_${DateFormat('yyyyMMdd_HHmmss').format(now)}';

  /// The print job's name (shown in the print screen and notification).
  static String printJobName(DateTime now) =>
      'ProAlbums_${DateFormat('yyyyMMdd_HHmmss').format(now)}';

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

/// How pictures are laid out for printing (the "Print" sheet).
final class PrintLayout {
  const PrintLayout({this.perSheet = 1, this.scalePercent = 100})
    : assert(perSheet > 0),
      assert(scalePercent > 0 && scalePercent <= 100);

  /// "Merge Multiple Pages": pictures on one sheet of paper.
  static const List<int> perSheetChoices = [1, 2, 4, 9];

  /// "Scale To": 50% .. 100%, in steps of 10.
  static const int minScale = 50;
  static const int maxScale = 100;
  static const int scaleStep = 10;

  final int perSheet;

  /// How big each picture is in its place (100 = as big as fits).
  final int scalePercent;

  PrintLayout copyWith({int? perSheet, int? scalePercent}) => PrintLayout(
    perSheet: perSheet ?? this.perSheet,
    scalePercent: scalePercent ?? this.scalePercent,
  );

  /// White space around the pictures on a sheet (PDF points, 1/72 inch).
  /// Merged sheets use less, so the small pictures get the room (like the
  /// system gallery).
  double get pageMargin => perSheet == 1 ? 24 : 12;

  /// Space between merged pictures (points).
  double get gap => perSheet == 1 ? 0 : 4;

  /// The grids [perSheet] pictures can use (columns, rows).
  List<(int, int)> get _grids => switch (perSheet) {
    1 => const [(1, 1)],
    2 => const [(1, 2), (2, 1)],
    4 => const [(2, 2)],
    9 => const [(3, 3)],
    _ => [(1, perSheet)],
  };

  /// The grid that shows pictures of [aspects] (width / height, in order)
  /// biggest on a [width] x [height] area (inside the margins): e.g. two
  /// tall screenshots side by side on a tall sheet, two wide photos one
  /// above the other.
  (int columns, int rows) bestGrid({
    required List<double> aspects,
    required double width,
    required double height,
  }) {
    var best = _grids.first;
    var bestArea = -1.0;
    for (final grid in _grids) {
      final (columns, rows) = grid;
      final cellWidth = (width - gap * (columns - 1)) / columns;
      final cellHeight = (height - gap * (rows - 1)) / rows;
      var area = 0.0;
      for (final aspect in aspects.take(columns * rows)) {
        final a = aspect > 0 ? aspect : 1.0;
        final w = cellWidth < cellHeight * a ? cellWidth : cellHeight * a;
        area += w * (w / a);
      }
      if (area > bestArea) {
        best = grid;
        bestArea = area;
      }
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is PrintLayout &&
      other.perSheet == perSheet &&
      other.scalePercent == scalePercent;

  @override
  int get hashCode => Object.hash(perSheet, scalePercent);
}
