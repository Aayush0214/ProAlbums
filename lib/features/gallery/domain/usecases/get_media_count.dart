import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';

final class GetMediaCount implements UseCase<int, MediaKind> {
  const GetMediaCount(this._repository);

  final MediaRepository _repository;

  @override
  FutureResult<int> call(MediaKind params) =>
      _repository.getMediaCount(params);
}
