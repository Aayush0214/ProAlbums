
import 'package:flutter/services.dart';

/// A fast thumbnail source: the thumbnails the phone already made itself.
/// Returns null when it cannot help, so the caller can use another way.
abstract interface class SystemThumbnailSource {
  Future<Uint8List?> load({
    required String id,
    required int size,
    required bool isVideo,
  });
}

/// Android: talks to SystemThumbnailChannel.kt.
final class MethodChannelSystemThumbnailSource implements SystemThumbnailSource {
  const MethodChannelSystemThumbnailSource();

  static const MethodChannel _channel =
      MethodChannel('com.aayush.proalbums/thumbnails');

  @override
  Future<Uint8List?> load({
    required String id,
    required int size,
    required bool isVideo,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('load', <String, Object>{
        'id': id,
        'size': size,
        'isVideo': isVideo,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // not Android, or an old build
    }
  }
}
