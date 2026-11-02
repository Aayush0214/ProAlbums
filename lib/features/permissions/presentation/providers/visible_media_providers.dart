import 'package:proalbums/features/permissions/data/repositories/photo_manager_visible_media_repository.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/domain/repositories/visible_media_repository.dart';
import 'package:proalbums/features/permissions/presentation/providers/library_access_revision.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'visible_media_providers.g.dart';

@Riverpod(keepAlive: true)
VisibleMediaRepository visibleMediaRepository(Ref ref) =>
    const PhotoManagerVisibleMediaRepository();

/// Can the app see any media? Re-checked whenever the person changes the
/// access ("Select more" / "Allow all"), see [LibraryAccessRevision].
@riverpod
Future<bool> hasVisibleMedia(Ref ref) {
  ref.watch(libraryAccessRevisionProvider);
  return ref.watch(visibleMediaRepositoryProvider).hasAny();
}

/// True when the person allowed only SOME photos ("Select photos") and none
/// is selected. The tabs then explain it instead of showing a blank screen.
///
/// Reads nothing from other features, and does no work unless the access
/// really is limited.
@riverpod
bool limitedLibraryIsEmpty(Ref ref) {
  final status = ref.watch(mediaPermissionProvider).value;
  if (status != MediaPermissionStatus.limited) return false;
  return ref.watch(hasVisibleMediaProvider).value == false;
}
