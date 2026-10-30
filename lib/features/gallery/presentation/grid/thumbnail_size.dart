import 'dart:math' as math;

/// Pixel size to request for a thumbnail tile.
///
/// Rounded UP to a multiple of 32 so tiny layout changes (rotation, 0.3px
/// differences) still ask for the SAME size and hit the image cache, and so we
/// never fetch a blurry, too-small image.
int thumbnailSizeFor({
  required double cellSize,
  required double devicePixelRatio,
}) {
  const step = 32;
  const minSize = 96;
  const maxSize = 512;

  final needed = cellSize * devicePixelRatio;
  final rounded = (needed / step).ceil() * step;
  return math.min(maxSize, math.max(minSize, rounded));
}
