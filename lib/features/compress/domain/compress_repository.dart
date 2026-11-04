import 'package:proalbums/features/compress/domain/compress_rules.dart';

/// The smaller copy that was saved: its gallery id and size.
typedef CompressedCopy = ({String id, int sizeBytes});

/// How a video compression ended.
sealed class VideoCompressResult {
  const VideoCompressResult();
}

final class VideoCompressed extends VideoCompressResult {
  const VideoCompressed(this.copy);
  final CompressedCopy copy;
}

final class VideoCompressCancelled extends VideoCompressResult {
  const VideoCompressCancelled();
}

final class VideoCompressFailed extends VideoCompressResult {
  const VideoCompressFailed();
}

/// Making smaller copies (the phone does the work; the original stays).
abstract interface class CompressRepository {
  Future<MediaCompressInfo?> imageInfo(String id);

  /// About how many bytes the copy at [scale] (0.2–1) and JPEG [quality]
  /// will have.
  Future<int?> estimateImage(
    String id, {
    required double scale,
    required int quality,
  });

  Future<CompressedCopy?> compressImage(
    String id, {
    required double scale,
    required int quality,
  });

  /// The picture kept for estimates is not needed any more.
  Future<void> forgetImage();

  Future<MediaCompressInfo?> videoInfo(String id);

  /// [onProgress] gets 0–100 while it runs.
  Future<VideoCompressResult> compressVideo(
    String id,
    VideoCompressOption option, {
    required void Function(int percent) onProgress,
  });

  Future<void> cancelVideo();
}

/// Which gallery items are copies made by Compress size (for the grid badge).
abstract interface class CompressedMediaRepository {
  /// id → size in bytes.
  Stream<Map<String, int>> watch();

  Future<void> remember(CompressedCopy copy);
}
