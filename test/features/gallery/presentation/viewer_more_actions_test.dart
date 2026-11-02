import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_more_actions.dart';

MediaItem _item(MediaType type) => MediaItem(
      id: '1',
      type: type,
      createdAt: DateTime(2026, 10, 12),
      width: 100,
      height: 100,
    );

void main() {
  test('a photo has 13 options, starting like the system gallery', () {
    final actions = moreActionsFor(_item(MediaType.image));
    expect(actions, hasLength(13));
    expect(actions.first, ViewerMoreAction.setAsWallpaper);
    expect(actions, contains(ViewerMoreAction.rotate));
    expect(actions, isNot(contains(ViewerMoreAction.convertToH264)));
  });

  test('a video has its own 8 options', () {
    final actions = moreActionsFor(_item(MediaType.video));
    expect(actions, hasLength(8));
    expect(actions, contains(ViewerMoreAction.convertToH264));
    expect(actions, isNot(contains(ViewerMoreAction.rotate)));
  });
}
