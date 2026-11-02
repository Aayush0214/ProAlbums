import 'dart:async';

import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/permissions/presentation/providers/library_access_revision.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Makes the provider [ref] belongs to load again a moment after
///  - the phone's library changed (a delete, a restore, a new photo), or
///  - what the app may see changed (more photos picked, "Allow all").
///
/// The wait joins a burst of changes (a delete of 50 photos) into ONE reload.
/// Call it at the start of the provider's body.
void reloadOnLibraryChange(
  Ref ref, {
  Duration delay = const Duration(milliseconds: 400),
}) {
  Timer? timer;
  void schedule(Object? previous, Object? next) {
    timer?.cancel();
    timer = Timer(delay, ref.invalidateSelf);
  }

  ref
    ..onDispose(() => timer?.cancel())
    ..listen(mediaLibraryChangesProvider, schedule)
    ..listen(libraryAccessRevisionProvider, schedule);
}
