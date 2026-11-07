import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/platform/screen_awake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the screen stays on while anyone wants it', () async {
    await ScreenAwake.keepOn(on: true, by: 'viewer');
    await ScreenAwake.keepOn(on: true, by: 'video');
    // The video pauses: the viewer still wants the screen on.
    await ScreenAwake.keepOn(on: false, by: 'video');
    expect(ScreenAwake.holders, {'viewer'});
    await ScreenAwake.keepOn(on: false, by: 'viewer');
    expect(ScreenAwake.holders, isEmpty);
  });
}
