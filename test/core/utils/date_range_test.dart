import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/utils/date_label.dart';

void main() {
  final now = DateTime(2026, 10, 30, 10);

  test('month label', () {
    expect(formatMonthLabel(DateTime(2026, 10)), 'October 2026');
  });

  group('formatDateRange', () {
    test('older day to today', () {
      expect(
        formatDateRange(DateTime(2026, 8, 28), DateTime(2026, 10, 30, 9), now: now),
        'August 28 - today',
      );
    });

    test('same day shows one label', () {
      expect(
        formatDateRange(DateTime(2026, 10, 12, 8), DateTime(2026, 10, 12, 20), now: now),
        'October 12',
      );
    });

    test('two older days', () {
      expect(
        formatDateRange(DateTime(2026, 9, 1), DateTime(2026, 10, 8), now: now),
        'September 1 - October 8',
      );
    });
  });
}
