import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';

/// The one-time "Media management" access that makes deleting dialog-free.
final class MediaManagementAccessUseCase {
  const MediaManagementAccessUseCase(this._repository);

  final TrashRepository _repository;

  Future<bool> isGranted() => _repository.hasMediaManagement();

  Future<bool> request() => _repository.requestMediaManagement();
}
