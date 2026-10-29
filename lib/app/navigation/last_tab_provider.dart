import 'dart:async';

import 'package:proalbums/app/navigation/last_tab_repository.dart';
import 'package:proalbums/app/navigation/main_tab.dart';
import 'package:proalbums/app/navigation/shared_prefs_last_tab_repository.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'last_tab_provider.g.dart';

@Riverpod(keepAlive: true)
LastTabRepository lastTabRepository(Ref ref) =>
    SharedPrefsLastTabRepository(ref.watch(sharedPreferencesProvider));

/// The tab the user last used. Its first value (build) is the SAVED tab, so:
///  - the router starts on it (initialLocation), and
///  - after the permission screen the user returns to it.
///
/// The bottom bar itself still shows `navigationShell.currentIndex`, which is
/// always correct. This provider is only "memory" of the last choice.
@Riverpod(keepAlive: true)
class LastTab extends _$LastTab {
  @override
  MainTab build() => ref.read(lastTabRepositoryProvider).read();

  void select(MainTab tab) {
    if (state == tab) return;
    state = tab;
    // Fire and forget: the repository never throws, and the UI must not wait
    // for a disk write.
    unawaited(ref.read(lastTabRepositoryProvider).save(tab));
  }
}
