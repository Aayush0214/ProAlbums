import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/features/compress/data/drift_compressed_media_repository.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';

void main() {
  group('videoOptionsFor', () {
    // The system gallery's example: 4K, 10 s, 29.56 MB.
    const fourK = MediaCompressInfo(
      width: 3840,
      height: 2160,
      sizeBytes: 30995000,
      durationMs: 10000,
    );

    test('its own size first, then every smaller step', () {
      final options = videoOptionsFor(fourK);
      expect(
        [for (final o in options) '${o.width}x${o.height}'],
        ['3840x2160', '1920x1080', '1280x720', '960x540', '854x480'],
      );
    });

    test(
      'every choice is smaller than the original, smaller sizes smaller',
      () {
        final options = videoOptionsFor(fourK);
        for (final option in options) {
          expect(option.estimatedBytes, lessThan(fourK.sizeBytes));
        }
        for (var i = 1; i < options.length; i++) {
          expect(
            options[i].estimatedBytes,
            lessThanOrEqualTo(options[i - 1].estimatedBytes),
          );
        }
      },
    );

    test('a portrait video keeps standing (short side = width)', () {
      final options = videoOptionsFor(
        const MediaCompressInfo(
          width: 1080,
          height: 1920,
          sizeBytes: 20000000,
          durationMs: 10000,
        ),
      );
      expect(
        [for (final o in options) '${o.width}x${o.height}'],
        ['1080x1920', '720x1280', '540x960', '480x854'],
      );
    });

    test('nothing to offer without a size or a length', () {
      expect(
        videoOptionsFor(
          const MediaCompressInfo(width: 0, height: 0, sizeBytes: 1),
        ),
        isEmpty,
      );
    });
  });

  group('Convert to H.264', () {
    test('1.4 × the original bitrate, so the look stays', () {
      // 4K HEVC, 10 s, 25 MB ≈ 20 Mbit/s video.
      const hevc = MediaCompressInfo(
        width: 3840,
        height: 2160,
        sizeBytes: 25000000,
        durationMs: 10000,
      );
      const expected = (25000000 * 8 / 10 - 128000) * 1.4;
      expect(h264BitrateFor(hevc), closeTo(expected, 1));
    });

    test('never below what the size needs, never above 60 Mbit/s', () {
      const tiny = MediaCompressInfo(
        width: 1920,
        height: 1080,
        sizeBytes: 100000,
        durationMs: 10000,
      );
      expect(h264BitrateFor(tiny), 10000000);
      const huge = MediaCompressInfo(
        width: 3840,
        height: 2160,
        sizeBytes: 500000000,
        durationMs: 10000,
      );
      expect(h264BitrateFor(huge), 60000000);
    });

    test('only H.264 counts as already standard', () {
      expect(isH264('video/avc'), isTrue);
      expect(isH264('video/hevc'), isFalse);
      expect(isH264(null), isFalse);
    });
  });

  test('JPEG quality: Lowest 40, Highest 95', () {
    expect(jpegQualityFor(0), 40);
    expect(jpegQualityFor(1), 95);
    expect(jpegQualityFor(0.5), 68);
  });

  test('sizes read like the system gallery', () {
    expect(formatMegabytes(2873098), '2.74 MB');
    expect(formatMegabytes(870000), '850 KB');
    expect(compressedBadgeText(13275000), '12.7M');
    expect(compressedBadgeText(870000), '850K');
  });

  test('compressed copies are remembered with their size', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = DriftCompressedMediaRepository(db);

    await repository.remember((id: '42', sizeBytes: 1000));
    await repository.remember((id: '42', sizeBytes: 900)); // made again

    expect(await repository.watch().first, {'42': 900});
  });
}
