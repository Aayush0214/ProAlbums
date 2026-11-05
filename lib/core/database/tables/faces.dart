import 'package:drift/drift.dart';

/// Intelligent classification > People: which pictures were looked at for
/// faces (again only when the file changed: [modified]).
class FaceScans extends Table {
  TextColumn get mediaId => text()();

  /// MediaStore DATE_MODIFIED (seconds) when it was looked at.
  IntColumn get modified => integer()();

  /// When the picture was taken (ms), for featured pictures / slideshows.
  IntColumn get takenMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}

/// One face found in a picture.
@TableIndex(name: 'faces_media', columns: {#mediaId})
@TableIndex(name: 'faces_person', columns: {#personId})
@DataClassName('FaceRow')
class Faces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mediaId => text()();

  /// Where, as a share (0–1) of the upright picture.
  RealColumn get left => real()();
  RealColumn get top => real()();
  RealColumn get right => real()();
  RealColumn get bottom => real()();

  /// Face width as a share of the picture's short side.
  RealColumn get size => real()();

  /// How sharp the face is (blurred = low).
  RealColumn get sharpness => real()();

  /// 128 float32 numbers (length 1): same person = close.
  BlobColumn get embedding => blob()();

  /// Who it is (null = nobody yet, or taken out with "Not this person").
  IntColumn get personId => integer().nullable()();

  /// Already given to a person (or left alone on purpose); false = new.
  BoolColumn get grouped => boolean().withDefault(const Constant(false))();
}

/// A person: a group of faces.
@DataClassName('PersonRow')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The name given with "Add name" (null = none).
  TextColumn get name => text().nullable()();

  /// The face chosen with "Set as cover" (null = the best one).
  IntColumn get coverFaceId => integer().nullable()();

  /// On the People page: true = added (+), false = hidden, null = decided
  /// by the app (the people with the most pictures).
  BoolColumn get shown => boolean().nullable()();

  /// Mean embedding of the faces (not length 1), to compare new faces.
  BlobColumn get centroid => blob()();

  /// Faces in the group.
  IntColumn get faceCount => integer()();

  /// Last change by the user (name, cover, merge, added): those come first.
  IntColumn get changedAt => integer().withDefault(const Constant(0))();
}

/// "Not this person": this face must never go back to this person.
class FaceRejections extends Table {
  IntColumn get faceId => integer()();
  IntColumn get personId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {faceId, personId};
}
