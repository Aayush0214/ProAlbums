import 'package:drift/drift.dart';

/// Cleanup suggestions: what was learned about each picture, so it is
/// looked at only once (again only when the file changed: [modified]).
class CleanupFingerprints extends Table {
  TextColumn get mediaId => text()();

  /// MediaStore DATE_MODIFIED (seconds) when this was made.
  IntColumn get modified => integer()();

  /// 64-bit difference hash of the picture (near pictures = near hashes).
  IntColumn get dhash => integer()();

  /// How sharp it is (blurred = low).
  RealColumn get sharpness => real()();

  /// SHA-1 of the file, only for pictures that share size and dimensions
  /// with another one (exact-duplicate check). null = not needed (yet).
  TextColumn get sha1 => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}
