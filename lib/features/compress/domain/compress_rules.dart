import 'dart:math' as math;

/// The Resolution slider of a picture: 20 % … 100 % of each side.
const List<double> imageScales = [0.2, 0.4, 0.6, 0.8, 1];

/// The Quality slider (0 = Lowest … 1 = Highest) as a JPEG quality.
/// Highest is 95, not 100: 100 makes files much bigger for no visible gain.
int jpegQualityFor(double slider) => (40 + 55 * slider.clamp(0, 1)).round();

/// A picture or video's upright size, bytes and length.
final class MediaCompressInfo {
  const MediaCompressInfo({
    required this.width,
    required this.height,
    required this.sizeBytes,
    this.durationMs = 0,
  });

  final int width;
  final int height;
  final int sizeBytes;
  final int durationMs;
}

/// One line of the video list: "1920x1080 (around 12.09 MB)".
final class VideoCompressOption {
  const VideoCompressOption({
    required this.width,
    required this.height,
    required this.bitrate,
    required this.estimatedBytes,
  });

  final int width;
  final int height;

  /// Video bits per second asked from the encoder.
  final int bitrate;
  final int estimatedBytes;

  @override
  bool operator ==(Object other) =>
      other is VideoCompressOption &&
      other.width == width &&
      other.height == height &&
      other.bitrate == bitrate;

  @override
  int get hashCode => Object.hash(width, height, bitrate);
}

/// The short sides offered below the video's own (like the system gallery).
const List<int> _videoLadder = [2160, 1080, 720, 540, 480];

/// Sound is kept as it is; this is about what it adds per second.
const int _audioBitrate = 128000;

/// The list for a video: its own resolution first, then every smaller step,
/// each with a bitrate that fits its size and never more than 85 % of what
/// the original uses (so every choice really is smaller).
List<VideoCompressOption> videoOptionsFor(MediaCompressInfo video) {
  final width = video.width;
  final height = video.height;
  if (width <= 0 || height <= 0 || video.durationMs <= 0) return const [];
  final short = math.min(width, height);
  final seconds = video.durationMs / 1000;
  final originalBitrate = video.sizeBytes * 8 / seconds;
  final ceiling = (originalBitrate - _audioBitrate) * 0.85;

  VideoCompressOption option(int w, int h) {
    final bitrate = math
        .max(500000, math.min(_bitrateFor(w * h), ceiling))
        .round();
    return VideoCompressOption(
      width: w,
      height: h,
      bitrate: bitrate,
      estimatedBytes: ((bitrate + _audioBitrate) * seconds / 8).round(),
    );
  }

  return [
    option(_even(width), _even(height)),
    for (final side in _videoLadder)
      if (side < short)
        width >= height
            ? option(_even(side * width / height), side)
            : option(side, _even(side * height / width)),
  ];
}

/// About 10 Mbit/s for 1080p, growing slower than the number of pixels
/// (bigger pictures compress better).
double _bitrateFor(int pixels) =>
    10000000 * math.pow(pixels / (1920 * 1080), 0.6).toDouble();

/// Encoders want even sides: 853.3 → 854.
int _even(num value) => (value / 2).round() * 2;

/// "2.74 MB", "850 KB", "1.20 GB".
String formatMegabytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  return '${math.max(1, (bytes / kb).round())} KB';
}

/// The grid badge of a compressed video: "12.6M", "850K", "1.2G".
String compressedBadgeText(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)}G';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)}M';
  return '${math.max(1, (bytes / kb).round())}K';
}
