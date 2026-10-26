import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';

/// `Result<T>` reads better than `Either<Failure, T>` everywhere.
/// Left = Failure, Right = success value.
typedef Result<T> = Either<Failure, T>;

typedef FutureResult<T> = Future<Result<T>>;
