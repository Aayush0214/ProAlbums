import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/widgets/gallery_items_row.dart';

MediaItem _item(String id) => MediaItem(
      id: id,
      type: MediaType.image,
      createdAt: DateTime(2026),
      width: 1,
      height: 1,
      duration: Duration.zero,
    );

void main() {
  final row = [for (final id in ['a', 'b', 'c', 'd']) _item(id)];

  test('bit i is set for item i in the set', () {
    expect(rowMask(row, {'a', 'c'}), 0x5); // 0101
    expect(rowMask(row, {'d'}), 0x8);
  });

  test('nothing of this row: 0 (so the row does not rebuild)', () {
    expect(rowMask(row, {'x', 'y'}), 0);
    expect(rowMask(row, const {}), 0);
  });

  test('a full 8-column row fits', () {
    final wide = [for (var i = 0; i < 8; i++) _item('$i')];
    expect(rowMask(wide, {for (var i = 0; i < 8; i++) '$i'}), 0xFF);
  });
}
