import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_session_provider.g.dart';

/// WHERE the viewer's swipe list comes from (the Photos tab list, an album's
/// list, search results ...).
///
/// A route can only carry text, so the screen that opens the viewer puts its
/// list here first and then goes to `/viewer/<id>`. This way the gallery never
/// has to know the other features (albums, search ...): they plug their own
/// list in. If nothing was set (e.g. the app was restored), the Photos tab
/// list is used.
@Riverpod(keepAlive: true)
class ViewerSession extends _$ViewerSession {
  @override
  ProviderListenable<List<MediaItem>> build() => photosDisplayItemsProvider;

  void start(ProviderListenable<List<MediaItem>> items) => state = items;
}
