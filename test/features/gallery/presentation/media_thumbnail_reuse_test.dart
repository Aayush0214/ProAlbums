import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';

Future<Uint8List?> _load(String id, int size) async => null;

/// Puts a finished (decoded) thumbnail of [id] at [size] into the cache.
Future<void> _cache(String id, int size) async {
  final image = await createTestImage(width: size, height: size);
  final provider = MediaThumbnailImage(id: id, size: size, load: _load);
  MediaThumbnailImage.debugRememberSize(size);
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => PaintingBinding.instance.imageCache.clear());

  test('zoom out: a bigger decoded copy is reused (smallest that fits)',
      () async {
    await _cache('a', 288);
    await _cache('a', 384);

    final ready = MediaThumbnailImage.readyAtLeast('a', 192, _load);
    expect(ready?.size, 288);
  });

  test('the exact size counts as ready', () async {
    await _cache('a', 288);
    expect(MediaThumbnailImage.readyAtLeast('a', 288, _load)?.size, 288);
  });

  test('zoom in: nothing big enough, the biggest smaller copy is the '
      'placeholder', () async {
    await _cache('a', 160);
    await _cache('a', 288);

    expect(MediaThumbnailImage.readyAtLeast('a', 384, _load), isNull);
    expect(MediaThumbnailImage.readyBelow('a', 384, _load)?.size, 288);
  });

  test('another photo\'s copies never count', () async {
    await _cache('b', 384);
    expect(MediaThumbnailImage.readyAtLeast('a', 192, _load), isNull);
    expect(MediaThumbnailImage.readyBelow('a', 512, _load), isNull);
  });
}
