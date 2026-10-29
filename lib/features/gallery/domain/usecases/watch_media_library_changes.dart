import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';

final class WatchMediaLibraryChanges implements StreamUseCase<Unit, NoParams> {
  const WatchMediaLibraryChanges(this._repository);

  final MediaRepository _repository;

  @override
  Stream<Result<Unit>> call(NoParams params) =>
      _repository.watchLibraryChanges();
}
