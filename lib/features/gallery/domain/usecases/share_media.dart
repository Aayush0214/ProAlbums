import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_share_repository.dart';

/// Share the chosen photos and videos.
final class ShareMediaUseCase {
  const ShareMediaUseCase(this._repository);

  final MediaShareRepository _repository;

  FutureResult<Unit> call(List<String> ids) => _repository.shareMedia(ids);
}
