import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/repositories/storage_repository.dart';

/// Talks to StorageChannel.kt (Android only).
final class MethodChannelStorageRepository implements StorageRepository {
  const MethodChannelStorageRepository();

  static const MethodChannel _channel =
      MethodChannel('com.aayush.proalbums/storage');

  @override
  FutureResult<StorageUsage> getUsage() async {
    try {
      final row = await _channel.invokeMapMethod<String, Object?>('usage');
      int read(String key) => (row?[key] as num?)?.toInt() ?? 0;
      return right<Failure, StorageUsage>(
        StorageUsage(
          total: read('total'),
          free: read('free'),
          photos: read('photos'),
          videos: read('videos'),
          screenshots: read('screenshots'),
          trash: read('trash'),
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not read the storage', error: error, stackTrace: stackTrace);
      return left<Failure, StorageUsage>(
        const MediaFailure('Could not read the storage.'),
      );
    }
  }
}
