import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/result_guard.dart';

void main() {
  group('guardAsync', () {
    test('wraps a normal value in Right', () async {
      final result = await guardAsync<int>(
        () async => 42,
        onError: (error, stackTrace) => const UnexpectedFailure('unused'),
      );

      expect(result, right<Failure, int>(42));
    });

    test('turns a thrown error into the mapped Failure (Left)', () async {
      final result = await guardAsync<int>(
        () async => throw StateError('boom'),
        onError: (error, stackTrace) => const MediaFailure('mapped'),
      );

      expect(result, left<Failure, int>(const MediaFailure('mapped')));
    });
  });
}
