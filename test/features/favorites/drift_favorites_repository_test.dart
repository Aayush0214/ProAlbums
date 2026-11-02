import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/features/favorites/data/repositories/drift_favorites_repository.dart';
import 'package:proalbums/features/favorites/domain/entities/favorite_location.dart';

void main() {
  late AppDatabase db;
  late DriftFavoritesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFavoritesRepository(db);
  });

  tearDown(() => db.close());

  test('getIds returns every favorite', () async {
    await repository.setFavorite(['1', '2'], value: true);
    expect(await repository.getIds(), {'1', '2'});
  });

  test('saveLocations fills the name and folder', () async {
    await repository.setFavorite(['1'], value: true);
    await repository.saveLocations(const [
      FavoriteLocation(
        mediaId: '1',
        displayName: 'IMG_1.jpg',
        relativePath: 'DCIM/Camera/',
      ),
    ]);
    final row = await db.select(db.favorites).getSingle();
    expect(row.displayName, 'IMG_1.jpg');
    expect(row.relativePath, 'DCIM/Camera/');
  });

  test('saveLocations does not overwrite a name that is already saved', () async {
    await repository.setFavorite(['1'], value: true);
    const first = FavoriteLocation(
      mediaId: '1',
      displayName: 'IMG_1.jpg',
      relativePath: 'DCIM/Camera/',
    );
    const second = FavoriteLocation(
      mediaId: '1',
      displayName: 'Other.jpg',
      relativePath: 'Pictures/',
    );
    await repository.saveLocations(const [first]);
    await repository.saveLocations(const [second]);
    final row = await db.select(db.favorites).getSingle();
    expect(row.displayName, 'IMG_1.jpg');
  });

  test('saveLocations ignores an id that is not a favorite', () async {
    await repository.saveLocations(const [
      FavoriteLocation(mediaId: 'x', displayName: 'a.jpg', relativePath: 'p/'),
    ]);
    expect(await db.select(db.favorites).get(), isEmpty);
  });
}
