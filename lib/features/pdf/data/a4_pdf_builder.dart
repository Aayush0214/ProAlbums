import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';

/// White space around the picture on each page of Convert PDF (PDF points,
/// 1/72 inch: 24 = about 8 mm). Same as an unmerged print sheet.
const double a4PageMargin = 24;

/// An A4 portrait PDF, one JPEG picture per page (Convert PDF). See
/// [buildPicturesPdfBytes].
Future<Uint8List> buildA4PdfBytes(List<Uint8List> jpegs) =>
    buildPicturesPdfBytes(jpegs, PdfPageFormat.a4);

/// A PDF of [format] pages (paper size + orientation, e.g. what the user
/// chose in the print screen) with the JPEG pictures in order.
///
/// [layout] (Print): [PrintLayout.perSheet] pictures share one sheet in the
/// grid that shows them biggest ([PrintLayout.bestGrid]: two tall
/// screenshots side by side, two wide photos one above the other; 4 = 2x2;
/// 9 = 3x3), and each picture is [PrintLayout.scalePercent] of the size
/// that fits its place. Pictures are centred, never cropped.
///
/// The JPEG bytes go into the PDF as they are (no decode, no re-encode), so
/// the file stays small and this is quick. Pure Dart: runs in a background
/// isolate.
Future<Uint8List> buildPicturesPdfBytes(
  List<Uint8List> jpegs,
  PdfPageFormat format, {
  PrintLayout layout = const PrintLayout(),
}) {
  final document = pw.Document(title: 'ProAlbums', creator: 'ProAlbums');
  final margin = layout.pageMargin;
  final scale = layout.scalePercent / 100;

  for (var start = 0; start < jpegs.length; start += layout.perSheet) {
    final sheet = [
      for (final jpeg in jpegs.skip(start).take(layout.perSheet))
        pw.MemoryImage(jpeg),
    ];
    final (columns, rows) = layout.bestGrid(
      aspects: [
        for (final image in sheet) (image.width ?? 1) / (image.height ?? 1),
      ],
      width: format.width - 2 * margin,
      height: format.height - 2 * margin,
    );
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(margin),
        build: (context) => pw.Column(
          children: [
            for (var row = 0; row < rows; row++)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.only(top: row == 0 ? 0 : layout.gap),
                  child: pw.Row(
                    children: [
                      for (var column = 0; column < columns; column++)
                        pw.Expanded(
                          child: pw.Padding(
                            padding: pw.EdgeInsets.only(
                              left: column == 0 ? 0 : layout.gap,
                            ),
                            child: _cell(sheet, row * columns + column, scale),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  return document.save();
}

/// One place of the grid: the picture at [index] scaled down by [scale]
/// inside it, or nothing (the last sheet may not be full).
pw.Widget _cell(List<pw.MemoryImage> sheet, int index, double scale) {
  if (index >= sheet.length) return pw.SizedBox();
  return pw.LayoutBuilder(
    builder: (context, constraints) => pw.Center(
      child: pw.SizedBox(
        width: constraints!.maxWidth * scale,
        height: constraints.maxHeight * scale,
        child: pw.Image(sheet[index], fit: pw.BoxFit.contain),
      ),
    ),
  );
}
