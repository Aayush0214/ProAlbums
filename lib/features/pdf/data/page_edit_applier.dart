import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';

/// [source] (a JPEG) with [spec] applied, as a new JPEG, and its size.
/// Pure Dart (package:image): runs in a background isolate.
///
/// Same order as the editor (extended_image): turn, mirror, then crop.
({Uint8List jpeg, int width, int height}) applyPdfPageEdit(
  Uint8List source,
  PdfPageEditSpec spec,
) {
  var picture = img.decodeImage(source);
  if (picture == null) throw const FormatException('Not a picture');
  picture = img.bakeOrientation(picture);
  if (spec.rotateDegrees % 360 != 0) {
    picture = img.copyRotate(picture, angle: spec.rotateDegrees);
  }
  if (spec.flip) {
    picture = img.flip(picture, direction: img.FlipDirection.horizontal);
  }
  if (spec.crop case final crop?) {
    picture = img.copyCrop(
      picture,
      x: crop.left.clamp(0, picture.width - 1),
      y: crop.top.clamp(0, picture.height - 1),
      width: crop.width.clamp(1, picture.width),
      height: crop.height.clamp(1, picture.height),
    );
  }
  return (
    jpeg: img.encodeJpg(picture, quality: 90),
    width: picture.width,
    height: picture.height,
  );
}
