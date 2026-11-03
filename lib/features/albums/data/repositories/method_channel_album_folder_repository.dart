import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/domain/repositories/album_folder_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Talks to FolderChannel.kt (Android only).
final class MethodChannelAlbumFolderRepository implements AlbumFolderRepository {
  const MethodChannelAlbumFolderRepository();

  static const MethodChannel _channel =
      MethodChannel('com.aayush.proalbums/folders');

  @override
  FutureResult<CreateFolderOutcome> createFolder(String name) async {
    try {
      final answer =
          await _channel.invokeMethod<String>('createFolder', {'name': name});
      return right<Failure, CreateFolderOutcome>(
        answer == 'exists'
            ? CreateFolderOutcome.alreadyExists
            : CreateFolderOutcome.created,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not create the album folder',
          error: error, stackTrace: stackTrace);
      return left<Failure, CreateFolderOutcome>(
        const MediaFailure('Could not create the album.'),
      );
    }
  }

  @override
  Future<List<String>> listFolderNames() async {
    try {
      final names = await _channel.invokeListMethod<String>('listFolders');
      return names ?? const <String>[];
    } on Object {
      return const <String>[];
    }
  }

  @override
  Future<bool> isPicturesFolder(String name) async {
    try {
      return await _channel
              .invokeMethod<bool>('isPicturesFolder', {'name': name}) ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> renameEmptyFolder(String from, String to) async {
    try {
      return await _channel.invokeMethod<bool>(
            'renameFolder',
            {'from': from, 'to': to},
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> removeFolderIfEmpty(String name) async {
    try {
      await _channel.invokeMethod<void>('removeIfEmpty', {'name': name});
    } on Object {
      // A leftover empty folder is harmless.
    }
  }

  @override
  Future<Set<String>> existingMediaIds(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const <String>{};
    try {
      final found =
          await _channel.invokeListMethod<String>('existingIds', {'ids': list});
      return {...?found};
    } on Object {
      return list.toSet();
    }
  }

  @override
  FutureResult<TransferResult> transfer(
    List<MediaItem> items,
    TransferTarget target, {
    required bool move,
    TransferProgress? onProgress,
  }) async {
    if (items.isEmpty) {
      return right<Failure, TransferResult>(
        const TransferResult(cancelled: false),
      );
    }
    // FolderChannel.kt calls back "transferProgress" while it works.
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'transferProgress' || onProgress == null) return;
      final args = call.arguments as Map<Object?, Object?>;
      onProgress(args['done']! as int, args['total']! as int);
    });
    try {
      final answer = await _channel.invokeMapMethod<String, Object?>('transfer', {
        'ids': [for (final item in items) item.id],
        'videos': [for (final item in items) item.isVideo],
        // The folder of this album, found on the Android side. When it has
        // no files (or no id), the files go to Pictures/<folder>.
        'albumId': target.albumId,
        'folder': target.name,
        'move': move,
      });
      final cancelled = answer?['status'] == 'cancelled';
      return right<Failure, TransferResult>(
        TransferResult(
          cancelled: cancelled,
          done: (answer?['done'] as int?) ?? 0,
          failed: (answer?['failed'] as int?) ?? 0,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not ${move ? 'move' : 'copy'} to the album',
          error: error, stackTrace: stackTrace);
      return left<Failure, TransferResult>(
        MediaFailure('Could not ${move ? 'move' : 'copy'} the selected items.'),
      );
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}
