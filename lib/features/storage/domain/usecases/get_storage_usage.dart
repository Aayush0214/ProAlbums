import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/repositories/storage_repository.dart';

/// How much storage is used, and by what.
final class GetStorageUsageUseCase {
  const GetStorageUsageUseCase(this._repository);

  final StorageRepository _repository;

  FutureResult<StorageUsage> call() => _repository.getUsage();
}
