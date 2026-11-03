
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// Talks to TrashChannel.kt (Android only; the ids are MediaStore ids).
final class MethodChannelTrashRepository implements TrashRepository {
  const MethodChannelTrashRepository();

  static const MethodChannel _channel =
      MethodChannel('com.aayush.proalbums/trash');

  @override
  Future<bool> hasMediaManagement() async {
    try {
      return await _channel.invokeMethod<bool>('canManage') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestMediaManagement() async {
    try {
      return await _channel.invokeMethod<bool>('requestManage') ?? false;
    } on Object {
      return false;
    }
  }

  Map<String, Object> _args(List<MediaItem> items) => {
        'ids': [for (final item in items) item.id],
        'videos': [for (final item in items) item.isVideo],
      };

  @override
  FutureResult<TrashOutcome> moveToTrash(List<MediaItem> items) async {
    if (items.isEmpty) return right<Failure, TrashOutcome>(TrashOutcome.trashed);
    try {
      final answer = await _channel.invokeMethod<String>('trash', _args(items));
      return right<Failure, TrashOutcome>(
        answer == 'trashed' ? TrashOutcome.trashed : TrashOutcome.cancelled,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not move to trash', error: error, stackTrace: stackTrace);
      return left<Failure, TrashOutcome>(
        const MediaFailure('Could not delete the selected items.'),
      );
    }
  }

  @override
  FutureResult<List<TrashedItem>> getTrashed() async {
    try {
      final rows = await _channel
          .invokeListMethod<Map<Object?, Object?>>('listTrashed');
      return right<Failure, List<TrashedItem>>([
        for (final row in rows ?? const <Map<Object?, Object?>>[]) _parse(row),
      ]);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not read the trash', error: error, stackTrace: stackTrace);
      return left<Failure, List<TrashedItem>>(
        const MediaFailure('Could not load "Recently deleted".'),
      );
    }
  }

  TrashedItem _parse(Map<Object?, Object?> row) {
    final video = row['video'] == true;
    final expiresMs = (row['expiresMs'] as num?)?.toInt() ?? 0;
    return TrashedItem(
      item: MediaItem(
        id: row['id']! as String,
        type: video ? MediaType.video : MediaType.image,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['createdMs'] as num?)?.toInt() ?? 0,
        ),
        width: (row['width'] as num?)?.toInt() ?? 0,
        height: (row['height'] as num?)?.toInt() ?? 0,
        duration: Duration(
          milliseconds: video ? (row['durationMs'] as num?)?.toInt() ?? 0 : 0,
        ),
      ),
      name: (row['name'] as String?) ?? '',
      path: (row['path'] as String?) ?? '',
      expiresAt:
          expiresMs > 0 ? DateTime.fromMillisecondsSinceEpoch(expiresMs) : null,
    );
  }

  Future<Either<Failure, TrashActionOutcome>> _action(
    String method,
    List<MediaItem> items,
    String failureText,
  ) async {
    if (items.isEmpty) {
      return right<Failure, TrashActionOutcome>(TrashActionOutcome.done);
    }
    try {
      final answer = await _channel.invokeMethod<String>(method, _args(items));
      return right<Failure, TrashActionOutcome>(
        answer == 'done' ? TrashActionOutcome.done : TrashActionOutcome.cancelled,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Trash action "$method" failed',
          error: error, stackTrace: stackTrace);
      return left<Failure, TrashActionOutcome>(MediaFailure(failureText));
    }
  }

  @override
  FutureResult<TrashActionOutcome> restore(List<MediaItem> items) =>
      _action('restore', items, 'Could not restore the selected items.');

  @override
  FutureResult<TrashActionOutcome> deleteForever(List<MediaItem> items) =>
      _action('deleteForever', items, 'Could not delete the selected items.');

  @override
  Future<Uint8List?> thumbnail({
    required String id,
    required bool isVideo,
    required int size,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('thumbnail', {
        'id': id,
        'video': isVideo,
        'size': size,
      });
    } on Object {
      return null;
    }
  }

  @override
  String playableVideoUri(String id) =>
      // Same MediaStore address as any video, asked to include the trash
      // (TrashChannel.kt reads thumbnails the same way).
      'content://media/external/video/media/$id?includeTrashed=1';
}
