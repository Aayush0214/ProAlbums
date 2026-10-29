/// 39s -> "00:39", 63s -> "01:03", 1h 2m 3s -> "1:02:03".
/// Used for the video badge on thumbnails.
String formatVideoDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return hours > 0
      ? '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}'
      : '${twoDigits(minutes)}:${twoDigits(seconds)}';
}
