import 'package:flutter/foundation.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';

/// What is under the middle line of the strip.
@immutable
final class FilmstripPoint {
  const FilmstripPoint(this.index, [this.videoFraction]);

  /// The item (photo / video) that is in the middle.
  final int index;

  /// Only when the middle line is on the OPENED video: how far into it, 0..1.
  final double? videoFraction;
}

/// The maths of the filmstrip, kept free of widgets so it can be tested.
///
/// Every item is one slot ([kFilmstripSlot] wide). The ONE exception: a video
/// that is playing is opened up into [frameCount] frames side by side, in the
/// same strip, between its neighbours (like the system gallery).
///
/// "Offset" is the scroll offset of the strip. The strip has equal padding on
/// both sides, so offset == where the start of the content is, minus half a
/// slot: item i is exactly in the middle when offset == start of item i.
@immutable
final class FilmstripLayout {
  const FilmstripLayout({
    required this.itemCount,
    this.videoIndex,
    this.frameCount = 0,
  });

  final int itemCount;

  /// The item that is opened up (null = none).
  final int? videoIndex;
  final int frameCount;

  bool get expanded => videoIndex != null && frameCount > 0;
  double get videoWidth => expanded ? frameCount * kVideoFrameWidth : 0;

  /// How many things the list builds (items, and frames for the open video).
  int get cellCount => expanded ? itemCount - 1 + frameCount : itemCount;

  double extentOfCell(int cell) {
    if (!expanded) return kFilmstripSlot;
    final e = videoIndex!;
    return (cell >= e && cell < e + frameCount)
        ? kVideoFrameWidth
        : kFilmstripSlot;
  }

  /// What list cell [cell] shows: an item, or a frame of the open video.
  ({int? item, int? frame}) cellAt(int cell) {
    if (!expanded) return (item: cell, frame: null);
    final e = videoIndex!;
    if (cell < e) return (item: cell, frame: null);
    if (cell < e + frameCount) return (item: null, frame: cell - e);
    return (item: cell - frameCount + 1, frame: null);
  }

  /// Where item [index] starts (the opened video pushes the ones after it).
  double startOfItem(int index) {
    var start = index * kFilmstripSlot;
    if (expanded && index > videoIndex!) start += videoWidth - kFilmstripSlot;
    return start;
  }

  /// Scroll offset that puts item [index] in the middle.
  double offsetForIndex(int index) => startOfItem(index);

  /// Scroll offset that puts the moment [fraction] (0..1) of the OPEN video in
  /// the middle.
  double offsetForVideoFraction(double fraction) =>
      startOfItem(videoIndex!) +
      fraction.clamp(0.0, 1.0) * videoWidth -
      kFilmstripSlot / 2;

  /// The reverse: what is in the middle at this scroll offset.
  FilmstripPoint pointAt(double offset) {
    if (itemCount <= 0) return const FilmstripPoint(0);
    var u = offset + kFilmstripSlot / 2;
    if (u < 0) u = 0;
    final last = itemCount - 1;

    if (!expanded) {
      return FilmstripPoint((u / kFilmstripSlot).floor().clamp(0, last));
    }
    final e = videoIndex!;
    final videoStart = e * kFilmstripSlot;
    final videoEnd = videoStart + videoWidth;

    if (u < videoStart) {
      return FilmstripPoint(
        (u / kFilmstripSlot).floor().clamp(0, e > 0 ? e - 1 : 0),
      );
    }
    if (u <= videoEnd) {
      return FilmstripPoint(e, ((u - videoStart) / videoWidth).clamp(0.0, 1.0));
    }
    return FilmstripPoint(
      (e + 1 + ((u - videoEnd) / kFilmstripSlot).floor()).clamp(0, last),
    );
  }
}
