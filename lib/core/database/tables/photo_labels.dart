import 'package:drift/drift.dart';

/// Intelligent classification > the things (Documents, Plants, Food…):
/// what ML Kit saw in each picture (looked at once; again only when the
/// file changed: [modified]).
class PhotoLabels extends Table {
  TextColumn get mediaId => text()();

  /// MediaStore DATE_MODIFIED (seconds) when it was looked at.
  IntColumn get modified => integer()();

  /// When the picture was taken (ms), for the newest-first order.
  IntColumn get takenMs => integer()();

  /// "Label:0.83,Label:0.71" (confidence ≥ 0.5); "" = nothing seen.
  TextColumn get labels => text()();

  /// Which camera took it (from the EXIF): "front", "back", "" = unknown.
  TextColumn get camera => text().withDefault(const Constant(''))();

  /// Documents: characters read (ML Kit text recognition) and the share of
  /// the picture covered by text.
  IntColumn get textChars => integer().withDefault(const Constant(0))();
  RealColumn get textArea => real().withDefault(const Constant(0))();

  /// Search: the text read (lower case, one space apart; "" = none).
  TextColumn get words => text().withDefault(const Constant(''))();

  /// In a Screenshots folder (never a document).
  BoolColumn get screenshot => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}

/// "Remove this type": pictures the user took out of a thing album
/// (nothing is deleted).
class ThingExclusions extends Table {
  TextColumn get mediaId => text()();

  /// ThingKind name.
  TextColumn get kind => text()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId, kind};
}
