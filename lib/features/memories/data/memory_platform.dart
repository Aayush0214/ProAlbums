import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';

/// How an export ended: [id] = saved to Movies/ProAlbums, [path] = a file
/// in the cache to share, [cancelled] = the user stopped it.
typedef ExportOutcome = ({String? id, String? path, bool cancelled});

/// A song's loudness (0–1 per bar) and length.
typedef SongWave = ({List<double> bars, int durationMs});

/// Talks to MemoryChannel.kt.
abstract interface class MemoryPlatform {
  /// Android's picker for a song; null = cancelled.
  Future<({String uri, String name})?> pickAudio();

  /// The picked song can still be opened.
  Future<bool> canRead(String uri);

  /// The song's loudness for the "choose a part" page; null = unreadable.
  Future<SongWave?> waveform(String uri, {int bars});

  /// The memory as an MP4 (see MemoryChannel.kt); null = failed.
  /// [toGallery] false = a file in the cache (to share). [onProgress]
  /// 0–100 while it is made.
  Future<ExportOutcome?> exportVideo({
    required List<String> ids,
    required String? audio,
    required int audioStartMs,
    required int perPictureMs,
    bool toGallery = true,
    void Function(int percent)? onProgress,
  });

  Future<void> cancelExport();
}

final class MethodChannelMemoryPlatform implements MemoryPlatform {
  const MethodChannelMemoryPlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/memories',
  );

  @override
  Future<({String uri, String name})?> pickAudio() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('pickAudio');
      if (map == null) return null;
      return (uri: map['uri']! as String, name: map['name'] as String? ?? '');
    } on Object catch (error, stackTrace) {
      AppLogger.e('Pick audio failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<SongWave?> waveform(String uri, {int bars = 120}) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('waveform', {
        'uri': uri,
        'bars': bars,
      });
      if (map == null) return null;
      return (
        bars: [
          for (final v in map['bars']! as List<Object?>) (v! as num).toDouble(),
        ],
        durationMs: (map['durationMs']! as num).toInt(),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Waveform failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<ExportOutcome?> exportVideo({
    required List<String> ids,
    required String? audio,
    required int audioStartMs,
    required int perPictureMs,
    bool toGallery = true,
    void Function(int percent)? onProgress,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'exportProgress') {
        final percent = (call.arguments as Map<Object?, Object?>)['percent'];
        if (percent is int) onProgress?.call(percent);
      }
    });
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'exportVideo',
        {
          'ids': ids,
          'audio': audio,
          'audioStartMs': audioStartMs,
          'perPictureMs': perPictureMs,
          'toGallery': toGallery,
        },
      );
      if (map == null) return null;
      return (
        id: map['id'] as String?,
        path: map['path'] as String?,
        cancelled: map['cancelled'] == true,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Export failed', error: error, stackTrace: stackTrace);
      return null;
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  @override
  Future<void> cancelExport() async {
    try {
      await _channel.invokeMethod<void>('cancelExport');
    } on Object catch (error, stackTrace) {
      AppLogger.e('Cancel export failed', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<bool> canRead(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('canRead', {'uri': uri}) ??
          false;
    } on Object catch (error, stackTrace) {
      AppLogger.e('Can read failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
