import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_video_tools.dart';

void main() {
  test('speed labels read like the system gallery', () {
    expect(speedLabel(1), '1.0x');
    expect(speedLabel(2), '2.0x');
    expect(speedLabel(0.5), '0.5x');
    expect(speedLabel(1.25), '1.25x');
  });

  test('speeds from slow to fast, normal included', () {
    expect(videoSpeeds, contains(1));
    expect(videoSpeeds, orderedEquals([...videoSpeeds]..sort()));
  });
}
