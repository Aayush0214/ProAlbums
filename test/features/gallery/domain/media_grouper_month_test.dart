import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/services/media_grouper.dart';

MediaItem _item(String id, DateTime at) => MediaItem(
      id: id,
      type: MediaType.image,
      createdAt: at,
      width: 1,
      height: 1,
    );

void main() {
  test('groups by month for the overview zoom level', () {
    final groups = MediaGrouper.group([
      _item('a', DateTime(2026, 10, 29)),
      _item('b', DateTime(2026, 10, 2)),
      _item('c', DateTime(2026, 9, 30)),
      _item('d', DateTime(2026, 8, 5)),
    ], GroupGranularity.month);

    expect(groups.map((g) => g.day), [
      DateTime(2026, 10),
      DateTime(2026, 9),
      DateTime(2026, 8),
    ]);
    expect(groups.first.items.length, 2);
    expect(groups.first.granularity, GroupGranularity.month);
  });
}
