import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';

final class GetMediaPage implements UseCase<MediaPage, MediaPageRequest> {
  const GetMediaPage(this._repository);

  final MediaRepository _repository;

  @override
  FutureResult<MediaPage> call(MediaPageRequest params) =>
      _repository.getMediaPage(params);
}
