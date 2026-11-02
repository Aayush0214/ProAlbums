import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';

void main() {
  test('only pictures: everything is on', () {
    final s = selectionMoreStates(hasImage: true, hasVideo: false);
    expect(s.values, everyElement(isTrue));
    expect(s.keys, SelectionMoreAction.values);
  });

  test('pictures + videos: only Hide and PDF/PPT are on', () {
    final s = selectionMoreStates(hasImage: true, hasVideo: true);
    expect(s[SelectionMoreAction.hide], isTrue);
    expect(s[SelectionMoreAction.pdfPpt], isTrue);
    expect(s[SelectionMoreAction.copyToClipboard], isFalse);
    expect(s[SelectionMoreAction.print], isFalse);
  });

  test('only videos: Hide only, the others stay visible but off', () {
    final s = selectionMoreStates(hasImage: false, hasVideo: true);
    expect(s[SelectionMoreAction.hide], isTrue);
    expect(s[SelectionMoreAction.pdfPpt], isFalse);
    expect(s[SelectionMoreAction.copyToClipboard], isFalse);
    expect(s[SelectionMoreAction.print], isFalse);
    expect(s, hasLength(4));
  });
}
