import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_clipboard_repository.dart';

/// Talks to ClipboardChannel.kt (Android only).
final class MethodChannelMediaClipboardRepository
    implements MediaClipboardRepository {
  const MethodChannelMediaClipboardRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/clipboard',
  );

  @override
  FutureResult<bool> copyImages(List<String> ids) async {
    try {
      final systemConfirms = await _channel.invokeMethod<bool>('copyImages', {
        'ids': ids,
      });
      return right<Failure, bool>(systemConfirms ?? false);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not copy to the clipboard',
        error: error,
        stackTrace: stackTrace,
      );
      return left<Failure, bool>(
        const MediaFailure('Could not copy the selected pictures.'),
      );
    }
  }
}
