import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/lifo_job_queue.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_frame_repository.dart';

/// Android: asks VideoFrameChannel.kt for a frame. Frames are remembered, so
/// scrolling back over the strip is instant.
///
/// A problem never throws: it answers null and the strip shows a plain box.
final class MethodChannelVideoFrameRepository implements VideoFrameRepository {
  MethodChannelVideoFrameRepository();

  static const MethodChannel _channel =
      MethodChannel('com.aayush.proalbums/video_frames');
  static const int _maxCachedFrames = 300;

  // Two at a time (the Android side works on one at a time anyway). The newest
  // request, the one that just scrolled into view, goes first.
  final LifoJobQueue _queue = LifoJobQueue(maxConcurrent: 2);
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _inflight =
      <String, Future<Uint8List?>>{};

  Future<Uint8List?> _decode(String id, Duration position, int size) {
    return _queue.run(() async {
      try {
        return await _channel.invokeMethod<Uint8List>('frame', <String, Object>{
          'id': id,
          'positionMs': position.inMilliseconds,
          'size': size,
        });
      } on PlatformException {
        return null;
      } on MissingPluginException {
        return null; // not Android
      }
    });
  }

  @override
  FutureResult<Uint8List?> frameAt({
    required String id,
    required Duration position,
    required int size,
  }) async {
    final key = '$id:${position.inMilliseconds}:$size';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // most recently used goes last
      return right<Failure, Uint8List?>(cached);
    }

    // The same frame can be asked twice (the strip tile AND the background
    // preload). Decode it only once.
    var pending = _inflight[key];
    if (pending == null) {
      pending = _decode(id, position, size);
      _inflight[key] = pending;
      unawaited(pending.whenComplete(() => _inflight.remove(key)));
    }
    final bytes = await pending;

    if (bytes != null) {
      _cache[key] = bytes;
      while (_cache.length > _maxCachedFrames) {
        _cache.remove(_cache.keys.first);
      }
    }
    return right<Failure, Uint8List?>(bytes);
  }
}
