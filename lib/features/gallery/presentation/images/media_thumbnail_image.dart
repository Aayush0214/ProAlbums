import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Loads the JPEG bytes of a preview. (Wired to the GetMediaThumbnail use case
/// by the MediaThumbnail widget, so this class stays free of Riverpod.)
typedef ThumbnailLoader = Future<Uint8List?> Function(String id, int size);

/// An ImageProvider for gallery thumbnails.
///
/// WHY this exists: Flutter keeps decoded images in a global [ImageCache].
/// The cache key is what `==` / `hashCode` say. We make the key
/// "(media id, size)", so the SAME photo is decoded and fetched only once, no
/// matter how many times its tile is rebuilt or scrolled back into view.
/// (`Image.memory(bytes)` is keyed by the bytes object, so a new fetch = a new
/// key = a cache miss every time.)
///
/// It is the "cached network image" idea, for local gallery items.
@immutable
class MediaThumbnailImage extends ImageProvider<MediaThumbnailImage> {
  const MediaThumbnailImage({
    required this.id,
    required this.size,
    required this.load,
  });

  final String id;
  final int size;

  /// Not part of the cache key on purpose (same photo = same key).
  final ThumbnailLoader load;

  @override
  Future<MediaThumbnailImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<MediaThumbnailImage>(this);

  @override
  ImageStreamCompleter loadImage(
    MediaThumbnailImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key, decode),
      scale: 1,
      debugLabel: 'MediaThumbnailImage(${key.id}, ${key.size})',
    );
  }

  Future<ui.Codec> _loadCodec(
    MediaThumbnailImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.load(key.id, key.size);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No thumbnail available for ${key.id}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is MediaThumbnailImage && other.id == id && other.size == size;

  @override
  int get hashCode => Object.hash(id, size);
}
