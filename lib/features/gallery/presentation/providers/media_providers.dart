import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/features/gallery/data/datasources/media_local_data_source.dart';
import 'package:proalbums/features/gallery/data/datasources/photo_manager_media_data_source.dart';
import 'package:proalbums/features/gallery/data/repositories/media_repository_impl.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/get_media_count.dart';
import 'package:proalbums/features/gallery/domain/usecases/get_media_page.dart';
import 'package:proalbums/features/gallery/domain/usecases/get_media_thumbnail.dart';
import 'package:proalbums/features/gallery/domain/usecases/watch_media_library_changes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_providers.g.dart';

// Dependency wiring for the gallery feature (same idea as permission_providers).

@Riverpod(keepAlive: true)
MediaLocalDataSource mediaLocalDataSource(Ref ref) {
  final dataSource = PhotoManagerMediaDataSource();
  ref.onDispose(dataSource.dispose);
  return dataSource;
}

@Riverpod(keepAlive: true)
MediaRepository mediaRepository(Ref ref) =>
    MediaRepositoryImpl(ref.watch(mediaLocalDataSourceProvider));

@Riverpod(keepAlive: true)
GetMediaPage getMediaPageUseCase(Ref ref) =>
    GetMediaPage(ref.watch(mediaRepositoryProvider));

@Riverpod(keepAlive: true)
GetMediaCount getMediaCountUseCase(Ref ref) =>
    GetMediaCount(ref.watch(mediaRepositoryProvider));

@Riverpod(keepAlive: true)
GetMediaThumbnail getMediaThumbnailUseCase(Ref ref) =>
    GetMediaThumbnail(ref.watch(mediaRepositoryProvider));

@Riverpod(keepAlive: true)
WatchMediaLibraryChanges watchMediaLibraryChangesUseCase(Ref ref) =>
    WatchMediaLibraryChanges(ref.watch(mediaRepositoryProvider));

/// Counts 1, 2, 3, ... every time the device library changes.
///
/// WHY a counter and not `Unit`? Riverpod only rebuilds listeners when the
/// new value is DIFFERENT from the old one. `unit == unit` is always equal,
/// so a plain Unit stream would never trigger a refresh.
@riverpod
Stream<int> mediaLibraryChanges(Ref ref) {
  var tick = 0;
  return ref
      .watch(watchMediaLibraryChangesUseCaseProvider)(const NoParams())
      .map((result) => result.fold((failure) => throw failure, (_) => ++tick));
}
