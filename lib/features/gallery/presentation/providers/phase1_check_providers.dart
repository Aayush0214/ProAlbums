import 'package:proalbums/features/gallery/domain/entities/media_page.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'phase1_check_providers.g.dart';

// TEMPORARY: only used by the Phase 1 verification screen (photos_page.dart).
// Phase 2 deletes this file and builds the real paged, grouped grid.
// (The thumbnail provider is gone: thumbnails now go through
// MediaThumbnailImage, which uses Flutter's own image cache.)

@riverpod
Future<int> mediaCount(Ref ref) async {
  ref.watch(mediaLibraryChangesProvider); // re-count when the library changes
  final result = await ref.watch(getMediaCountUseCaseProvider)(MediaKind.all);
  return result.fold((failure) => throw failure, (count) => count);
}

@riverpod
Future<MediaPage> firstMediaPage(Ref ref) async {
  ref.watch(mediaLibraryChangesProvider);
  final result = await ref.watch(getMediaPageUseCaseProvider)(
    const MediaPageRequest(page: 0, pageSize: 200),
  );
  return result.fold((failure) => throw failure, (page) => page);
}
