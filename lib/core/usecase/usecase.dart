

import 'package:proalbums/core/utils/typedefs.dart';

/// One use case = one thing the user can do ("load photos", "move to trash").
/// It talks only to repository INTERFACES (domain layer), never to plugins.
///
/// Why bother? The UI calls `getPhotos(params)` and does not care whether the
/// data comes from photo_manager, a database or a fake in tests.
abstract interface class UseCase<Output, Params> {
  FutureResult<Output> call(Params params);
}

/// Same idea for data that keeps changing (e.g. media library updates).
abstract interface class StreamUseCase<Output, Params> {
  Stream<Result<Output>> call(Params params);
}

/// Use this as `Params` when a use case needs no input.
final class NoParams {
  const NoParams();
}
