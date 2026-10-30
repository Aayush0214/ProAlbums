import 'dart:async';

/// Runs async jobs with at most [maxConcurrent] running at the same time.
///
/// WHY: the Photos grid asks for a thumbnail for every tile that appears.
/// Each thumbnail makes Android read and decode a whole photo (often 3-12 MB).
/// Doing 10-20 of those in parallel saturates the CPU and starves Flutter's own
/// UI/raster threads, which is what you feel as lag.
///
/// WHY LIFO (newest waiting job first): when the user scrolls, the tiles that
/// just appeared are the ones that matter. Tiles that were requested earlier
/// have probably scrolled out of view already.
final class LifoJobQueue {
  LifoJobQueue({required this.maxConcurrent}) : assert(maxConcurrent > 0);

  final int maxConcurrent;

  final List<void Function()> _waiting = <void Function()>[];
  int _running = 0;

  int get pendingCount => _waiting.length;
  int get runningCount => _running;

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _waiting.add(() => unawaited(_execute(task, completer)));
    _pump();
    return completer.future;
  }

  Future<void> _execute<T>(
    Future<T> Function() task,
    Completer<T> completer,
  ) async {
    _running++; // runs synchronously, before the first await
    try {
      completer.complete(await task());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _running--;
      _pump();
    }
  }

  void _pump() {
    while (_running < maxConcurrent && _waiting.isNotEmpty) {
      _waiting.removeLast()();
    }
  }
}
