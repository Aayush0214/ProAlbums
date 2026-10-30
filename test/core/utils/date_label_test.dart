import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/utils/date_label.dart';

void main() {
  // Thursday, 29 October 2026
  final now = DateTime(2026, 10, 29, 15, 30);

  group('formatDayLabel', () {
    test('today', (){
      final label = formatDayLabel(DateTime(2026, 10, 29), now: now);
      expect(label.title, 'Today');
      expect(label.subtitle, 'October 29');
      debugPrint('Today: $label');
    });
    test('yesterday', (){
      final label = formatDayLabel(DateTime(2026, 10, 28), now: now);
      expect(label.title, 'Yesterday');
      debugPrint('Yesterday: $label');
    });

    test('same year shows month and day plus the weekday', () {
      final label = formatDayLabel(DateTime(2026, 10, 12), now: now);
      expect(label.title, 'October 12');
      expect(label.subtitle, 'Monday');
      debugPrint('October 12, Monday: $label');
    });

    test('another year includes the year', () {
      final label = formatDayLabel(DateTime(2025, 3, 5), now: now);
      expect(label.title, 'March 5, 2025');
      expect(label.subtitle, 'Wednesday');
      debugPrint('March 5, 2025, Wednesday: $label');
    });

    test('yesterday works across a month boundary', () {
      final label = formatDayLabel(DateTime(2026, 9, 30), now: DateTime(2026, 10, 1, 9));
      expect(label.title, 'Yesterday');
      debugPrint('Yesterday: $label');
    });
  });
}