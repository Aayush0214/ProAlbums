import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/trash/domain/services/trash_days.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);

  group('trashDaysLeft', () {
    test('no date from Android = the full 30 days', () {
      expect(trashDaysLeft(null, now), 30);
    });
    test('a started day counts as a day', () {
      expect(trashDaysLeft(now.add(const Duration(days: 29, hours: 3)), now), 30);
      expect(trashDaysLeft(now.add(const Duration(days: 28, hours: 3)), now), 29);
    });
    test('exactly N days left', () {
      expect(trashDaysLeft(now.add(const Duration(days: 5)), now), 5);
    });
    test('less than a day left is 1', () {
      expect(trashDaysLeft(now.add(const Duration(hours: 2)), now), 1);
    });
    test('already expired is 0', () {
      expect(trashDaysLeft(now.subtract(const Duration(days: 1)), now), 0);
    });
    test('never more than 30', () {
      expect(trashDaysLeft(now.add(const Duration(days: 90)), now), 30);
    });
  });

  group('trashDaysLabel', () {
    test('singular and plural', () {
      expect(trashDaysLabel(1), '1 day');
      expect(trashDaysLabel(29), '29 days');
      expect(trashDaysLabel(0), '0 days');
    });
  });
}
