import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// "Remove this type": the pictures leave the thing shown in [albumId]
/// (nothing is deleted; they stay in the library and other albums).
Future<bool> removeFromThing(
  BuildContext context,
  WidgetRef ref,
  String? albumId,
  List<MediaItem> items,
) async {
  final kind = thingOfAlbum(albumId);
  if (kind == null || items.isEmpty) return false;
  await ref.read(thingStoreProvider).remove(kind, [
    for (final item in items) item.id,
  ]);
  ref.read(thingScanProvider.notifier).changed();
  return true;
}
