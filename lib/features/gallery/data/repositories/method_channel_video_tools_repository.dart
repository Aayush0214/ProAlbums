import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_tools_repository.dart';

/// Talks to VideoToolsChannel.kt (Android only).
final class MethodChannelVideoToolsRepository implements VideoToolsRepository {
  const MethodChannelVideoToolsRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/video_tools',
  );

  @override
  Future<Uint8List?> captureFrame(String id, Duration position) async {
    try {
      return await _channel.invokeMethod<Uint8List>('captureFrame', {
        'id': id,
        'positionMs': position.inMilliseconds,
      });
    } on Object catch (error, stackTrace) {
      AppLogger.e('Frame capture failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<double> brightness() => _number('brightness', fallback: 0.5);

  @override
  Future<void> setBrightness(double? value) async {
    try {
      await _channel.invokeMethod<void>('setBrightness', {'value': value});
    } on Object catch (error, stackTrace) {
      AppLogger.e('Brightness failed', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<double> volume() => _number('volume', fallback: 0.5);

  @override
  Future<double> setVolume(double value) =>
      _number('setVolume', arguments: {'value': value}, fallback: value);

  @override
  Future<SubtitleFile?> pickSubtitle() async {
    try {
      final answer = await _channel.invokeMapMethod<String, String>(
        'pickSubtitle',
      );
      final name = answer?['name'];
      final text = answer?['text'];
      if (name == null || text == null) return null;
      return (name: name, text: text);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Subtitle pick failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<double> _number(
    String method, {
    required double fallback,
    Map<String, Object?>? arguments,
  }) async {
    try {
      final value = await _channel.invokeMethod<num>(method, arguments);
      return value?.toDouble() ?? fallback;
    } on Object catch (error, stackTrace) {
      AppLogger.e('$method failed', error: error, stackTrace: stackTrace);
      return fallback;
    }
  }
}
