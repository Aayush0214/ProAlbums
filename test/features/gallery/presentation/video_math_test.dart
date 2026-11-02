import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_math.dart';

void main() {
  group('videoFrameCount', () {
    test('about one frame per 2 seconds', () {
      expect(videoFrameCount(const Duration(seconds: 40)), 20);
    });
    test('short clips still get 8 frames', () {
      expect(videoFrameCount(const Duration(seconds: 3)), 8);
      expect(videoFrameCount(Duration.zero), 8);
    });
    test('very long videos stop at 150', () {
      expect(videoFrameCount(const Duration(hours: 2)), 150);
    });
  });

  test('frame time is the middle of its part', () {
    expect(
      videoFrameTime(index: 0, frameCount: 10, duration: const Duration(seconds: 20)),
      const Duration(seconds: 1),
    );
  });

  test('formatClock', () {
    expect(formatClock(const Duration(seconds: 39)), '00:39');
    expect(formatClock(const Duration(minutes: 1, seconds: 2)), '01:02');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
  });
}
