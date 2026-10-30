import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/utils/lifo_job_queue.dart';

void main() {
  test('never runs more than maxConcurrent jobs at once', () async {
    final queue = LifoJobQueue(maxConcurrent: 2);
    var running = 0;
    var maxSeen = 0;

    Future<int> job(int id) => queue.run(() async {
          running++;
          maxSeen = math.max(maxSeen, running);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          running--;
          return id;
        });

    final results = await Future.wait([for (var i = 0; i < 6; i++) job(i)]);

    expect(results, [0, 1, 2, 3, 4, 5]); // every caller gets its own result
    expect(maxSeen, 2);
  });

  test('the newest waiting job runs first', () async {
    final queue = LifoJobQueue(maxConcurrent: 1);
    final order = <int>[];
    final gate = Completer<void>();

    final first = queue.run(() async {
      await gate.future;
      order.add(0);
    });
    final a = queue.run(() async => order.add(1));
    final b = queue.run(() async => order.add(2));
    final c = queue.run(() async => order.add(3));

    gate.complete();
    await Future.wait([first, a, b, c]);

    expect(order, [0, 3, 2, 1]);
  });

  test('an error reaches its caller and does not block the queue', () async {
    final queue = LifoJobQueue(maxConcurrent: 1);

    final failing = queue.run<int>(() async => throw StateError('boom'));
    final fine = queue.run(() async => 7);

    await expectLater(failing, throwsStateError);
    expect(await fine, 7);
  });
}
