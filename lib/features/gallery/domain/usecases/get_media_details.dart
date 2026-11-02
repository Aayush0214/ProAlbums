import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_details_repository.dart';

/// The details shown in the viewer's Info card.
final class GetMediaDetailsUseCase {
  const GetMediaDetailsUseCase(this._repository);

  final MediaDetailsRepository _repository;

  FutureResult<MediaDetails?> call(String id) => _repository.load(id);
}
