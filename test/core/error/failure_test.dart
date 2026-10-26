import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/error/failures.dart';

void main() {
  group('Failure', () {
    test('same type and message are equal', () {
      expect(
        const PermissionFailure('denied'),
        equals(const PermissionFailure('denied')),
      );
    });

    test('different message is not equal', () {
      expect(
        const PermissionFailure('denied'),
        isNot(equals(const PermissionFailure('limited'))),
      );
    });

    test('different type is not equal even with same message', () {
      expect(
        const MediaFailure('oops'),
        isNot(equals(const StorageFailure('oops'))),
      );
    });

    test('toString shows type and message', () {
      expect(
        const DatabaseFailure('locked').toString(),
        'DatabaseFailure(locked)',
      );
    });
  });
}
