import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/permissions/domain/repositories/media_permission_repository.dart';

final class PresentLimitedAccess implements UseCase<Unit, NoParams> {
  const PresentLimitedAccess(this._repository);

  final MediaPermissionRepository _repository;

  @override
  FutureResult<Unit> call(NoParams params) =>
      _repository.presentLimitedPicker();
}
