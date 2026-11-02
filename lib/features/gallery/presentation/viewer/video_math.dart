import 'dart:math' as math;

/// Width of one frame of an opened video in the filmstrip.
const double kVideoFrameWidth = 64;

/// Height of those frames.
const double kVideoFrameHeight = 54;

/// How many frames the strip shows for a video: about one every 2 seconds,
/// but at least 8 (short clips) and at most 150 (very long videos).
int videoFrameCount(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return (seconds / 2).ceil().clamp(8, 150);
}

/// The moment of the video that frame [index] shows (the middle of its part).
Duration videoFrameTime({
  required int index,
  required int frameCount,
  required Duration duration,
}) {
  final fraction = (index + 0.5) / math.max(1, frameCount);
  return Duration(milliseconds: (fraction * duration.inMilliseconds).round());
}

/// "00:31" or "1:02:05".
String formatClock(Duration duration) {
  final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
