import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_clipboard_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/copy_to_clipboard.dart';

final class _FakeClipboard implements MediaClipboardRepository {
  List<String>? copied;

  @override
  FutureResult<bool> copyImages(List<String> ids) async {
    copied = ids;
    return right<Failure, bool>(true);
  }
}

MediaItem _item(String id, MediaType type) => MediaItem(
  id: id,
  type: type,
  createdAt: DateTime(2026),
  width: 1,
  height: 1,
);

void main() {
  test('pictures are copied, in their order', () async {
    final clipboard = _FakeClipboard();
    final result = await CopyToClipboardUseCase(clipboard)([
      _item('2', MediaType.image),
      _item('1', MediaType.image),
    ]);
    expect(result.isRight(), isTrue);
    expect(clipboard.copied, ['2', '1']);
  });

  test('a video in the selection: nothing is copied', () async {
    final clipboard = _FakeClipboard();
    final result = await CopyToClipboardUseCase(clipboard)([
      _item('1', MediaType.image),
      _item('2', MediaType.video),
    ]);
    expect(result.isLeft(), isTrue);
    expect(clipboard.copied, isNull);
  });

  test('nothing selected: nothing is copied', () async {
    final clipboard = _FakeClipboard();
    final result = await CopyToClipboardUseCase(clipboard)(const []);
    expect(result.isLeft(), isTrue);
    expect(clipboard.copied, isNull);
  });
}
