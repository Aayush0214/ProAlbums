import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// The words of the delete dialog, picked by WHAT is being deleted (one photo,
/// one video, or several) and by WHERE it goes: the "Recently deleted" trash
/// ([toTrash] true, the default) or gone for good (the setting is off). Pure,
/// so it is tested.
({String title, String message, String confirm}) deleteDialogTexts(
  List<MediaItem> items, {
  bool toTrash = true,
}) {
  if (items.length == 1) {
    final noun = items.first.isVideo ? 'video' : 'image';
    return (
      title: 'Delete this $noun?',
      message: toTrash
          ? 'This $noun will be deleted from all albums synchronously and '
              'moved to "Recently deleted".'
          : 'This $noun will be permanently deleted from all albums. It '
              'cannot be recovered.',
      confirm: 'Delete',
    );
  }
  return (
    title: 'Delete ${items.length} items?',
    message: toTrash
        ? 'Any selected item will be deleted from all albums and moved to '
            '"Recently deleted".'
        : 'Any selected item will be permanently deleted from all albums. '
            'They cannot be recovered.',
    confirm: 'Delete',
  );
}
