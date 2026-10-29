import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/utils/duration_format.dart';

void main() {
  group('formatVideoDuration', () {
    test('formats seconds as mm:ss', () {
      expect(formatVideoDuration(const Duration(seconds: 39)), '00:39');
      expect(formatVideoDuration(const Duration(seconds: 63)), '01:03');
    });

    test('shows hours only when needed', () {
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('zero is 00:00', () {
      expect(formatVideoDuration(Duration.zero), '00:00');
    });
  });
}
