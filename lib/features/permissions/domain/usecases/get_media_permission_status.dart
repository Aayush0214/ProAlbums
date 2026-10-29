import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/domain/repositories/media_permission_repository.dart';

final class GetMediaPermissionStatus
    implements UseCase<MediaPermissionStatus, NoParams> {
  const GetMediaPermissionStatus(this._repository);

  final MediaPermissionRepository _repository;

  @override
  FutureResult<MediaPermissionStatus> call(NoParams params) =>
      _repository.getStatus();
}
