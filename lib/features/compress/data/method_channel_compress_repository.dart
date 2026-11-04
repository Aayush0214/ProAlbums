import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';

/// Talks to MediaCompressChannel.kt (Android only).
final class MethodChannelCompressRepository implements CompressRepository {
  const MethodChannelCompressRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/compress',
  );

  @override
  Future<MediaCompressInfo?> imageInfo(String id) => _info('imageInfo', id);

  @override
  Future<MediaCompressInfo?> videoInfo(String id) => _info('videoInfo', id);

  Future<MediaCompressInfo?> _info(String method, String id) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(method, {
        'id': id,
      });
      if (map == null) return null;
      return MediaCompressInfo(
        width: (map['width']! as num).toInt(),
        height: (map['height']! as num).toInt(),
        sizeBytes: (map['size']! as num).toInt(),
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('$method failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<int?> estimateImage(
    String id, {
    required double scale,
    required int quality,
  }) async {
    try {
      final bytes = await _channel.invokeMethod<num>('estimateImage', {
        'id': id,
        'scale': scale,
        'quality': quality,
      });
      return bytes?.toInt();
    } on Object catch (error, stackTrace) {
      AppLogger.e('estimateImage failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<CompressedCopy?> compressImage(
    String id, {
    required double scale,
    required int quality,
  }) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'compressImage',
        {'id': id, 'scale': scale, 'quality': quality},
      );
      return _copyOf(map);
    } on Object catch (error, stackTrace) {
      AppLogger.e('compressImage failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> forgetImage() async {
    try {
      await _channel.invokeMethod<void>('forget');
    } on Object {
      // Nothing to free.
    }
  }

  @override
  Future<VideoCompressResult> compressVideo(
    String id,
    VideoCompressOption option, {
    required void Function(int percent) onProgress,
  }) => _encode({
    'id': id,
    'width': option.width,
    'height': option.height,
    'bitrate': option.bitrate,
  }, onProgress);

  @override
  Future<VideoCompressResult> convertToH264(
    String id, {
    required int bitrate,
    required void Function(int percent) onProgress,
  }) => _encode({'id': id, 'bitrate': bitrate}, onProgress);

  @override
  Future<String?> videoCodec(String id) async {
    try {
      return await _channel.invokeMethod<String>('videoCodec', {'id': id});
    } on Object catch (error, stackTrace) {
      AppLogger.e('videoCodec failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Both make an H.264 copy (the same native call); no size = same size.
  Future<VideoCompressResult> _encode(
    Map<String, Object?> arguments,
    void Function(int percent) onProgress,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'compressProgress') {
        final percent = (call.arguments as Map?)?['percent'];
        if (percent is num) onProgress(percent.toInt());
      }
    });
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'compressVideo',
        arguments,
      );
      if (map?['cancelled'] == true) return const VideoCompressCancelled();
      final copy = _copyOf(map);
      return copy == null ? const VideoCompressFailed() : VideoCompressed(copy);
    } on Object catch (error, stackTrace) {
      AppLogger.e('compressVideo failed', error: error, stackTrace: stackTrace);
      return const VideoCompressFailed();
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  @override
  Future<void> cancelVideo() async {
    try {
      await _channel.invokeMethod<void>('cancelVideo');
    } on Object {
      // Already over.
    }
  }

  CompressedCopy? _copyOf(Map<String, Object?>? map) {
    final id = map?['id'];
    final size = map?['size'];
    if (id is! String || size is! num) return null;
    return (id: id, sizeBytes: size.toInt());
  }
}
