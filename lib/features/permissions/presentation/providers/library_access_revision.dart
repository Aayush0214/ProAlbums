import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_access_revision.g.dart';

/// Goes up by one every time WHAT THE APP IS ALLOWED TO SEE changes: the person
/// picked more photos ("Select more") or the permission changed in Settings
/// (limited -> all).
///
/// WHY it exists: Android sends NO "library changed" event for these. The
/// Photos tab was refreshed by hand, but the Albums, the album contents, the
/// storage numbers and "Recently deleted" were not, so they kept showing what
/// was visible BEFORE. They listen to this counter (see
/// `reloadOnLibraryChange`) and load again.
///
/// A counter and not a bool: Riverpod only tells listeners about a value that
/// is DIFFERENT from the old one.
@Riverpod(keepAlive: true)
class LibraryAccessRevision extends _$LibraryAccessRevision {
  @override
  int build() => 0;

  void bump() => state++;
}
