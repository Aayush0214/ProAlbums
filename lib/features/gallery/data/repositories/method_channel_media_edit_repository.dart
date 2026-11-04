import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_edit_repository.dart';

/// Talks to MediaEditChannel.kt (Android only).
final class MethodChannelMediaEditRepository implements MediaEditRepository {
  const MethodChannelMediaEditRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/media_edit',
  );

  Map<String, Object?> _of(MediaItem item) => {
    'id': item.id,
    'video': item.isVideo,
  };

  @override
  Future<String?> fileName(MediaItem item) async {
    try {
      return await _channel.invokeMethod<String>('name', _of(item));
    } on Object catch (error, stackTrace) {
      AppLogger.e('File name failed', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<MediaEditOutcome> rename(MediaItem item, String baseName) =>
      _change('rename', {..._of(item), 'name': baseName});

  @override
  Future<MediaEditOutcome> rotate(MediaItem item) =>
      _change('rotate', _of(item));

  @override
  Future<bool> openGoogleLens(MediaItem item) => _open('googleLens', item);

  @override
  Future<bool> setAsContactPhoto(MediaItem item) => _open('contactPhoto', item);

  Future<MediaEditOutcome> _change(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final answer = await _channel.invokeMethod<String>(method, arguments);
      return switch (answer) {
        'ok' => MediaEditOutcome.done,
        'exists' => MediaEditOutcome.nameTaken,
        'unsupported' => MediaEditOutcome.unsupported,
        'cancelled' => MediaEditOutcome.cancelled,
        _ => MediaEditOutcome.failed,
      };
    } on Object catch (error, stackTrace) {
      AppLogger.e('$method failed', error: error, stackTrace: stackTrace);
      return MediaEditOutcome.failed;
    }
  }

  Future<bool> _open(String method, MediaItem item) async {
    try {
      return await _channel.invokeMethod<bool>(method, _of(item)) ?? false;
    } on Object catch (error, stackTrace) {
      AppLogger.e('$method failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
