import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';

/// Saves collages into Pictures/Collage (the "Collage" album) through
/// CollageChannel.kt. Each answers the new picture's gallery id, or null.
abstract interface class CollageRepository {
  /// The collage as drawn (raw RGBA, [width] × [height]).
  Future<String?> saveRgba(
    Uint8List rgba, {
    required int width,
    required int height,
  });

  /// Pictures [ids] one under the other at [width] pixels.
  Future<String?> stitch(List<String> ids, {required int width});
}

final class MethodChannelCollageRepository implements CollageRepository {
  const MethodChannelCollageRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/collage',
  );

  @override
  Future<String?> saveRgba(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => _call('saveRgba', {'rgba': rgba, 'width': width, 'height': height});

  @override
  Future<String?> stitch(List<String> ids, {required int width}) =>
      _call('stitch', {'ids': ids, 'width': width});

  Future<String?> _call(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<String>(method, arguments);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Collage $method failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
