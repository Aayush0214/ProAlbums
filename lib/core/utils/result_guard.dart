import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';

/// Runs [body] and turns ANY thrown error into a [Failure] (Left).
///
/// WHY: every repository method needs the same try/catch. Writing it once here
/// keeps repositories short and guarantees no raw exception leaks out of the
/// data layer (see failure.dart).
FutureResult<T> guardAsync<T>(
  Future<T> Function() body, {
  required Failure Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    return right(await body());
  } catch (error, stackTrace) {
    final failure = onError(error, stackTrace);
    AppLogger.e(failure.message, error: error, stackTrace: stackTrace);
    return left(failure);
  }
}
