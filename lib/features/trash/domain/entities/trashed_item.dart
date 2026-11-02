import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// One picture / video that is in Android's trash ("Recently deleted").
final class TrashedItem {
  const TrashedItem({
    required this.item,
    required this.name,
    required this.path,
    required this.expiresAt,
  });

  /// Id, type, size and date, like any other picture of the app.
  final MediaItem item;

  /// "IMG_1.jpg"
  final String name;

  /// The file inside the phone (the trash keeps it there, hidden). Used to
  /// draw the small picture.
  final String path;

  /// When Android removes it for good. null when Android gave no date.
  final DateTime? expiresAt;

  String get id => item.id;
}
