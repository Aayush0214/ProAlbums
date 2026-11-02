import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/services/format_bytes.dart';

const int gb = 1024 * 1024 * 1024;

void main() {
  group('formatBytes', () {
    test('small sizes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1536), '1.5 KB');
    });
    test('MB and GB', () {
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(5 * gb), '5.0 GB');
      expect(formatBytes(237 * gb), '237 GB');
    });
  });

  group('formatPercent', () {
    test('rounds sensibly', () {
      expect(formatPercent(0), '0%');
      expect(formatPercent(0.004), '<1%');
      expect(formatPercent(0.0685), '6.9%');
      expect(formatPercent(0.443), '44%');
    });
  });

  group('StorageUsage', () {
    test('used is total - free, other is the rest', () {
      const u = StorageUsage(
        total: 100 * gb, free: 40 * gb,
        photos: 10 * gb, videos: 20 * gb, screenshots: gb, trash: gb,
      );
      expect(u.used, 60 * gb);
      expect(u.other, 28 * gb);
    });
    test('other is never negative', () {
      const u = StorageUsage(
        total: 10 * gb, free: 9 * gb,
        photos: 5 * gb, videos: 0, screenshots: 0, trash: 0,
      );
      expect(u.other, 0);
    });
    test('free larger than total does not break used', () {
      const u = StorageUsage(
        total: 10, free: 20, photos: 0, videos: 0, screenshots: 0, trash: 0,
      );
      expect(u.used, 0);
    });
  });
}
