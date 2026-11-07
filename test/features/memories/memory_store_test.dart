import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';

MemoryDraft draft(
  String key,
  List<String> ids, {
  String title = 'Fine Day',
  MemoryKind kind = MemoryKind.day,
  int start = 1000,
}) => MemoryDraft(
  kind: kind,
  key: key,
  title: title,
  startMs: start,
  endMs: start + ids.length,
  ids: ids,
  times: [for (var i = 0; i < ids.length; i++) start + i],
  shown: ids.take(2).toList(),
  coverId: ids.first,
);

void main() {
  late AppDatabase db;
  late MemoryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = MemoryStore(db);
  });

  tearDown(() => db.close());

  test('saves the memories with their shown pictures', () async {
    await store.sync(
      [
        draft('day:a', ['1', '2', '3']),
      ],
      {'1', '2', '3'},
    );
    final saved = await store.memories();
    expect(saved.single.key, 'day:a');
    expect(saved.single.shown, ['1', '2']);
    expect(saved.single.candidates, 3);
    expect(saved.single.coverId, '1');
  });

  test('the next run follows the rules for untouched memories', () async {
    await store.sync(
      [
        draft('day:a', ['1', '2']),
      ],
      {'1', '2', '3'},
    );
    await store.sync(
      [
        draft('day:a', ['3', '2']),
      ],
      {'1', '2', '3'},
    );
    expect((await store.memories()).single.shown, ['3', '2']);
  });

  test('a memory the rules no longer make goes', () async {
    await store.sync(
      [
        draft('day:a', ['1']),
      ],
      {'1'},
    );
    await store.sync(const [], {'1'});
    expect(await store.memories(), isEmpty);
  });

  test('a deleted memory is never made again (pictures untouched)', () async {
    await store.sync(
      [
        draft('day:a', ['1']),
      ],
      {'1'},
    );
    final id = (await store.memories()).single.id;
    await store.delete([id]);
    await store.sync(
      [
        draft('day:a', ['1']),
      ],
      {'1'},
    );
    expect(await store.memories(), isEmpty);
  });

  test('a renamed memory keeps its name', () async {
    await store.sync(
      [
        draft('day:a', ['1']),
      ],
      {'1'},
    );
    final id = (await store.memories()).single.id;
    await store.rename(id, '  Goa trip ');
    await store.sync(
      [
        draft('day:a', ['1'], title: 'Fine Day'),
      ],
      {'1'},
    );
    expect((await store.memories()).single.title, 'Goa trip');
  });

  test('multi-year memories first, then newest first', () async {
    await store.sync(
      [
        draft('day:old', ['1'], start: 10),
        draft('day:new', ['2'], start: 5000),
        draft('group', ['3', '4'], kind: MemoryKind.groupPhotos, start: 20),
      ],
      {'1', '2', '3', '4'},
    );
    expect(
      [for (final m in await store.memories()) m.key],
      ['group', 'day:new', 'day:old'],
    );
  });
}
