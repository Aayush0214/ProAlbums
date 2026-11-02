import 'dart:math' as math;

/// Pixels of the longer side of the picture we load for the viewer: the
/// screen's longer side (in pixels) rounded UP to a multiple of 128, at least
/// 1080 and at most 2560. Few distinct sizes = the image cache is reused.
int viewerImageLongEdge(double screenLongestSidePx) {
  final rounded = (screenLongestSidePx / 128).ceil() * 128;
  return math.min(2560, math.max(1080, rounded));
}

/// Which page to show after the photo list changed (a photo was added or
/// deleted while the viewer is open).
///
/// Keeps showing the SAME photo ([currentId]) even if its position moved. If
/// it was deleted, stays near the old position. -1 when the list is empty.
int resolveViewerIndex({
  required List<String> ids,
  required String? currentId,
  required int lastIndex,
}) {
  if (ids.isEmpty) return -1;
  final found = currentId == null ? -1 : ids.indexOf(currentId);
  if (found >= 0) return found;
  return lastIndex.clamp(0, ids.length - 1);
}

/// Width of one picture slot in the filmstrip.
const double kFilmstripSlot = 40;
