import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/services/format_bytes.dart';

const int gb = 1000 * 1000 * 1000;

void main() {
  group('formatBytes', () {
    test('small sizes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1500), '1.5 KB');
    });
    test('MB and GB, 1000 based like Settings and the file manager', () {
      expect(formatBytes(5 * 1000 * 1000), '5.0 MB');
      expect(formatBytes(5 * gb), '5.0 GB');
      expect(formatBytes(237 * gb), '237 GB');
    });
    test('the phone of the bug report: 128 GB, 65.6 GB free, 62.4 used', () {
      const u = StorageUsage(
        total: 128 * gb,
        free: 65600000000,
        photos: 0,
        videos: 0,
        screenshots: 0,
        trash: 0,
      );
      expect(formatBytes(u.total), '128 GB');
      expect(formatBytes(u.free), '65.6 GB');
      expect(formatBytes(u.used), '62.4 GB');
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
    test('hidden (vault) is its own part, not inside Other', () {
      const u = StorageUsage(
        total: 100 * gb,
        free: 40 * gb,
        photos: 10 * gb,
        videos: 20 * gb,
        screenshots: gb,
        trash: gb,
        hidden: 3 * gb,
      );
      expect(u.other, 25 * gb);
      expect(u.segments.map((s) => s.kind), contains(StorageKind.hidden));
    });
    test('folders (Camera, WhatsApp, Downloads) are cards, not ring parts', () {
      const u = StorageUsage(
        total: 100 * gb,
        free: 40 * gb,
        photos: 10 * gb,
        videos: 20 * gb,
        screenshots: gb,
        trash: gb,
        camera: 15 * gb,
        whatsapp: 4 * gb,
        downloads: gb,
      );
      final kinds = u.segments.map((s) => s.kind);
      expect(kinds, isNot(contains(StorageKind.camera)));
      expect(kinds, isNot(contains(StorageKind.whatsapp)));
      expect(kinds, isNot(contains(StorageKind.downloads)));
      // They do not change Other (they are inside photos / videos).
      expect(u.other, 28 * gb);
      expect(u.bytesOf(StorageKind.camera), 15 * gb);
      expect(u.bytesOf(StorageKind.free), 40 * gb);
    });
    test('used is total - free, other is the rest', () {
      const u = StorageUsage(
        total: 100 * gb,
        free: 40 * gb,
        photos: 10 * gb,
        videos: 20 * gb,
        screenshots: gb,
        trash: gb,
      );
      expect(u.used, 60 * gb);
      expect(u.other, 28 * gb);
    });
    test('other is never negative', () {
      const u = StorageUsage(
        total: 10 * gb,
        free: 9 * gb,
        photos: 5 * gb,
        videos: 0,
        screenshots: 0,
        trash: 0,
      );
      expect(u.other, 0);
    });
    test('free larger than total does not break used', () {
      const u = StorageUsage(
        total: 10,
        free: 20,
        photos: 0,
        videos: 0,
        screenshots: 0,
        trash: 0,
      );
      expect(u.used, 0);
    });
  });
}
