import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';

abstract interface class StorageRepository {
  FutureResult<StorageUsage> getUsage();
}
