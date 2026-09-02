import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/storage/app_database.dart';
import 'package:guten_speak/core/utils/narration_segmenter.dart';
import 'package:guten_speak/features/narration/data/datasources/synth_cache_data_source.dart';
import 'package:guten_speak/features/narration/data/repositories/synth_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _profileA = 'profile-a';
const _profileB = 'profile-b';

NarrationUnit _unit(int i) =>
    NarrationUnit(index: i, paragraphIndex: i, text: 'unit $i');

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late Directory audioRoot;
  late SynthCache cache;

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    // synth_cache rows FK-reference books; seed the book we render against.
    await db.insert(Db.books, <String, Object?>{
      Db.bookId: 1,
      Db.bookTitle: 'Book',
      Db.bookAuthor: 'Author',
      Db.bookPath: '/books/1',
      Db.bookDownloadedAt: 0,
    });
    audioRoot = await Directory.systemTemp.createTemp('gs_synth_cache');
    cache = SynthCache(SynthCacheDataSource(db), audioRoot);
  });

  tearDown(() async {
    await db.close();
    if (audioRoot.existsSync()) await audioRoot.delete(recursive: true);
  });

  /// Reserves, writes [bytes] to, and records a clip for one unit under a
  /// profile — the same reserve→synthesize→record flow the scheduler drives.
  Future<String> render(String profileId, int index, {int bytes = 8}) async {
    final path = await cache.reservePath(1, 'v', profileId, index);
    await File(path).writeAsBytes(List<int>.filled(bytes, 0));
    await cache.record(1, 'v', profileId, _unit(index));
    return path;
  }

  test('two profiles keep separate files and rows for the same unit', () async {
    final pathA = await render(_profileA, 0);
    final pathB = await render(_profileB, 0);

    expect(pathA, isNot(pathB));
    expect(pathA, contains('/$_profileA/'));
    expect(pathB, contains('/$_profileB/'));
    expect(File(pathA).existsSync(), isTrue);
    expect(File(pathB).existsSync(), isTrue);

    expect(await cache.cachedPath(1, 'v', _profileA, _unit(0)), pathA);
    expect(await cache.cachedPath(1, 'v', _profileB, _unit(0)), pathB);

    final rows = await db.query(Db.synthCache);
    expect(rows, hasLength(2));
  });

  test("evicting one profile's window leaves the other intact", () async {
    final keepA = await render(_profileA, 5);
    final dropA = await render(_profileA, 0);
    final keepB = await render(_profileB, 0);

    // Evict profile A outside [4, 8]: unit 0 goes, unit 5 stays.
    await cache.evictOutsideWindow(1, 'v', _profileA, lo: 4, hi: 8);

    expect(File(dropA).existsSync(), isFalse);
    expect(File(keepA).existsSync(), isTrue);
    // Profile B's unit 0 is untouched.
    expect(File(keepB).existsSync(), isTrue);
    expect(await cache.cachedPath(1, 'v', _profileB, _unit(0)), keepB);
    expect(await cache.cachedPath(1, 'v', _profileA, _unit(0)), isNull);
  });

  test('invalidateBook removes every profile for the book', () async {
    final a = await render(_profileA, 0);
    final b = await render(_profileB, 0);

    await cache.invalidateBook(1);

    expect(File(a).existsSync(), isFalse);
    expect(File(b).existsSync(), isFalse);
    expect(await db.query(Db.synthCache), isEmpty);
  });

  test('invalidateVoice removes clips across all profiles', () async {
    final a = await render(_profileA, 0);
    final b = await render(_profileB, 0);

    await cache.invalidateVoice('v');

    expect(File(a).existsSync(), isFalse);
    expect(File(b).existsSync(), isFalse);
    expect(await db.query(Db.synthCache), isEmpty);
  });

  test('cachedPath drops the row when its file is missing', () async {
    final path = await render(_profileA, 0);
    await File(path).delete();

    expect(await cache.cachedPath(1, 'v', _profileA, _unit(0)), isNull);
    expect(await db.query(Db.synthCache), isEmpty);
  });

  test('bytesPerBook sums clips across profile subdirectories', () async {
    await render(_profileA, 0, bytes: 100);
    await render(_profileB, 0, bytes: 40);

    final perBook = await cache.bytesPerBook();
    expect(perBook[1], 140);
  });
}
