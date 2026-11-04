import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// How a change to one photo / video ended.
enum MediaEditOutcome {
  done,

  /// Rename: another file in the same folder already has that name.
  nameTaken,

  /// Rotate: this kind of picture cannot be turned (only JPEG, PNG, WebP).
  unsupported,

  /// The person said no to Android's "Allow ProAlbums to modify…?".
  cancelled,
  failed,
}

/// The viewer's "More" actions that change or hand over ONE item.
abstract interface class MediaEditRepository {
  /// The file name with its extension ("IMG_20261104_101500.jpg"), or null.
  Future<String?> fileName(MediaItem item);

  /// New name [baseName] (WITHOUT extension: the old one is kept).
  Future<MediaEditOutcome> rename(MediaItem item, String baseName);

  /// Turns a picture 90° clockwise (the original itself, via its EXIF
  /// orientation: nothing is re-saved, no quality is lost).
  Future<MediaEditOutcome> rotate(MediaItem item);

  /// Opens Google Lens with this picture. false = no Google Lens here.
  Future<bool> openGoogleLens(MediaItem item);

  /// Android's "set as contact photo" (the Contacts app picks the contact and
  /// crops). false = no app can do it.
  Future<bool> setAsContactPhoto(MediaItem item);
}

/// Characters a file name may not hold on Android's shared storage.
const String forbiddenNameCharacters = r'\/:*?"<>|';

/// What is wrong with [baseName] as a new file name, or null when it is fine.
String? renameProblem(String baseName) {
  final name = baseName.trim();
  if (name.isEmpty) return 'Enter a name';
  if (name.startsWith('.')) return 'A name cannot start with a dot';
  for (final character in forbiddenNameCharacters.split('')) {
    if (name.contains(character)) {
      return r'A name cannot contain \ / : * ? " < > |';
    }
  }
  // Android allows 255 bytes; leave room for the extension.
  if (name.length > 200) return 'This name is too long';
  return null;
}

/// "IMG_1234.jpg" → "IMG_1234" (what the Rename field starts with).
String baseNameOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}
