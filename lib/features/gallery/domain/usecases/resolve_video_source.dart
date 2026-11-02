import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_source_repository.dart';

/// Find the file the video player should open.
final class ResolveVideoSourceUseCase {
  const ResolveVideoSourceUseCase(this._repository);

  final VideoSourceRepository _repository;

  FutureResult<String?> call(String id) => _repository.resolvePath(id);
}
