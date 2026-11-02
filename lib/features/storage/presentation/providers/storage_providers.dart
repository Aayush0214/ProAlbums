import 'dart:async';

import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/storage/data/repositories/method_channel_storage_repository.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/repositories/storage_repository.dart';
import 'package:proalbums/features/storage/domain/usecases/get_storage_usage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_providers.g.dart';

@Riverpod(keepAlive: true)
StorageRepository storageRepository(Ref ref) =>
    const MethodChannelStorageRepository();

@Riverpod(keepAlive: true)
GetStorageUsageUseCase getStorageUsageUseCase(Ref ref) =>
    GetStorageUsageUseCase(ref.watch(storageRepositoryProvider));

/// The storage numbers. Loads again a moment after the phone's library
/// changed (a delete, a restore, a new photo), so the card stays right.
@riverpod
Future<StorageUsage> storageUsage(Ref ref) async {
  Timer? timer;
  ref
    ..onDispose(() => timer?.cancel())
    ..listen(mediaLibraryChangesProvider, (previous, next) {
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 800), ref.invalidateSelf);
    });
  final result = await ref.watch(getStorageUsageUseCaseProvider)();
  return result.fold((failure) => throw failure, (usage) => usage);
}
