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

  /// Every size that was ever loaded. A handful (one per zoom level), so
  /// looking through it for a ready image is cheap.
  static final List<int> _sizesLoaded = <int>[];

  /// This photo already decoded (in the image cache, not still loading) at
  /// [size] or BIGGER: the smallest such. Drawing it costs no decode and no
  /// GPU upload. null when there is none.
  ///
  /// WHY: every zoom level asks for its own thumbnail size, so after a zoom
  /// every tile on screen used to be decoded and uploaded again at once
  /// (a ~150 ms burst of slow frames). A bigger copy drawn smaller looks the
  /// same.
  static MediaThumbnailImage? readyAtLeast(
    String id,
    int size,
    ThumbnailLoader load,
  ) {
    MediaThumbnailImage? best;
    for (final candidate in _sizesLoaded) {
      if (candidate < size || (best != null && candidate >= best.size)) continue;
      final provider = MediaThumbnailImage(id: id, size: candidate, load: load);
      if (_isReady(provider)) best = provider;
    }
    return best;
  }

  /// The biggest copy of this photo already decoded SMALLER than [size]:
  /// shown (a little soft) while the right size loads, so the tile is not
  /// empty. null when there is none.
  static MediaThumbnailImage? readyBelow(
    String id,
    int size,
    ThumbnailLoader load,
  ) {
    MediaThumbnailImage? best;
    for (final candidate in _sizesLoaded) {
      if (candidate >= size || (best != null && candidate <= best.size)) continue;
      final provider = MediaThumbnailImage(id: id, size: candidate, load: load);
      if (_isReady(provider)) best = provider;
    }
    return best;
  }

  /// Tests put images into the cache directly (without [loadImage]).
  @visibleForTesting
  static void debugRememberSize(int size) {
    if (!_sizesLoaded.contains(size)) _sizesLoaded.add(size);
  }

  static bool _isReady(MediaThumbnailImage provider) {
    final status = PaintingBinding.instance.imageCache.statusForKey(provider);
    return status.keepAlive || (status.live && !status.pending);
  }

  @override
  Future<MediaThumbnailImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<MediaThumbnailImage>(this);

  @override
  ImageStreamCompleter loadImage(
    MediaThumbnailImage key,
    ImageDecoderCallback decode,
  ) {
    if (!_sizesLoaded.contains(key.size)) _sizesLoaded.add(key.size);
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key, decode),
      scale: 1,
      // No debugLabel: building this string for every thumbnail showed up in
      // the profile (ImageProvider.toString), and only debug tools read it.
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
