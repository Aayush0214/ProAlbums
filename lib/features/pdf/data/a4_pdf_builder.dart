import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// White space around the picture on each page (PDF points, 1/72 inch:
/// 24 = about 8 mm).
const double a4PageMargin = 24;

/// An A4 portrait PDF, one JPEG picture per page (Convert PDF). See
/// [buildPicturesPdfBytes].
Future<Uint8List> buildA4PdfBytes(List<Uint8List> jpegs) =>
    buildPicturesPdfBytes(jpegs, PdfPageFormat.a4);

/// A PDF of [format] pages (paper size + orientation, e.g. what the user
/// chose in the print screen), one JPEG picture per page, each picture as
/// large as fits inside the margins, centred, never cropped.
///
/// The JPEG bytes go into the PDF as they are (no decode, no re-encode), so
/// the file stays small and this is quick. Pure Dart: runs in a background
/// isolate.
Future<Uint8List> buildPicturesPdfBytes(
  List<Uint8List> jpegs,
  PdfPageFormat format,
) {
  final document = pw.Document(title: 'ProAlbums', creator: 'ProAlbums');
  for (final jpeg in jpegs) {
    final image = pw.MemoryImage(jpeg);
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(a4PageMargin),
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return document.save();
}
