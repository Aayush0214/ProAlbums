import 'package:proalbums/core/utils/typedefs.dart';

extension ResultValue<T> on Result<T> {
  /// The success value, or throws the [Failure] (Left).
  ///
  /// Used inside Riverpod notifiers: a thrown Failure becomes an AsyncError,
  /// which is exactly how the UI learns "loading / data / error".
  T valueOrThrow() => fold((failure) => throw failure, (value) => value);
}