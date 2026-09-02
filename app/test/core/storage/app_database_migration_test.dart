import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/storage/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v5 `synth_cache` schema, keyed by `(book_id, voice_id, unit_index)`
/// before the profile-aware column existed. Rebuilt here so the migration can
/// be exercised against a genuine pre-v6 database.
Future<void> _createV5Schema(Database db) async {
  await db.execute('''
    CREATE TABLE ${Db.books} (
      ${Db.bookId} INTEGER PRIMARY KEY,
      ${Db.bookTitle} TEXT NOT NULL,
      ${Db.bookAuthor} TEXT NOT NULL,
      ${Db.bookPath} TEXT NOT NULL,
      ${Db.bookLanguage} TEXT,
      ${Db.bookCoverUrl} TEXT,
      ${Db.bookDownloadedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Db.synthCache} (
      ${Db.synthBookId} INTEGER NOT NULL
        REFERENCES ${Db.books} (${Db.bookId}) ON DELETE CASCADE,
      ${Db.synthVoiceId} TEXT NOT NULL,
      ${Db.synthUnitIndex} INTEGER NOT NULL,
      ${Db.synthUnitHash} TEXT NOT NULL,
      ${Db.synthFile} TEXT NOT NULL,
      ${Db.synthBytes} INTEGER NOT NULL,
      ${Db.synthCreatedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Db.synthBookId}, ${Db.synthVoiceId}, ${Db.synthUnitIndex})
    )
  ''');
}

Future<Database> _openV5(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 5,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createV5Schema(db),
    ),
  );
}

Future<String> _tempDbPath() async {
  final dir = await Directory.systemTemp.createTemp('gs_db_migration');
  addTearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });
  return p.join(dir.path, 'guten_speak.db');
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('fresh v6 database has a profile-aware synth_cache primary key', () async {
    final db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    addTearDown(db.close);

    final columns = await db.rawQuery(
      'PRAGMA table_info(${Db.synthCache})',
    );
    final pkColumns =
        columns.where((c) => (c['pk'] as int) > 0).map((c) => c['name']).toSet();

    expect(
      pkColumns,
      <String>{
        Db.synthBookId,
        Db.synthVoiceId,
        Db.synthUnitIndex,
        Db.synthProfileId,
      },
    );
  });

  test('v5→v6 migration recreates a profile-aware, empty synth_cache',
      () async {
    final path = await _tempDbPath();

    // Pre-release: no shipped audio to preserve, so the migration drops any
    // pre-v6 rows and rebuilds the table with the profile-aware key.
    final v5 = await _openV5(databaseFactoryFfi, path);
    await v5.insert(Db.books, <String, Object?>{
      Db.bookId: 1,
      Db.bookTitle: 'Book',
      Db.bookAuthor: 'Author',
      Db.bookPath: '/books/1',
      Db.bookDownloadedAt: 0,
    });
    await v5.insert(Db.synthCache, <String, Object?>{
      Db.synthBookId: 1,
      Db.synthVoiceId: 'reginald',
      Db.synthUnitIndex: 0,
      Db.synthUnitHash: 'hash0',
      Db.synthFile: '/audio/1/reginald/unit_0.wav',
      Db.synthBytes: 4242,
      Db.synthCreatedAt: 111,
    });
    await v5.close();

    final v6 = await openAppDatabase(databaseFactoryFfi, path);
    addTearDown(v6.close);

    final columns = await v6.rawQuery('PRAGMA table_info(${Db.synthCache})');
    final pkColumns =
        columns.where((c) => (c['pk'] as int) > 0).map((c) => c['name']).toSet();
    expect(
      pkColumns,
      <String>{
        Db.synthBookId,
        Db.synthVoiceId,
        Db.synthUnitIndex,
        Db.synthProfileId,
      },
    );
    expect(await v6.query(Db.synthCache), isEmpty);
  });

  test('two profiles can coexist for the same book/voice/unit', () async {
    final db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    addTearDown(db.close);

    await db.insert(Db.books, <String, Object?>{
      Db.bookId: 1,
      Db.bookTitle: 'Book',
      Db.bookAuthor: 'Author',
      Db.bookPath: '/books/1',
      Db.bookDownloadedAt: 0,
    });

    for (final profileId in <String>[
      'sherpa-profile-id',
      'raven-profile-id',
    ]) {
      await db.insert(Db.synthCache, <String, Object?>{
        Db.synthBookId: 1,
        Db.synthVoiceId: 'reginald',
        Db.synthUnitIndex: 0,
        Db.synthProfileId: profileId,
        Db.synthUnitHash: 'hash0',
        Db.synthFile: '/audio/1/reginald/$profileId/unit_0.wav',
        Db.synthBytes: 10,
        Db.synthCreatedAt: 0,
      });
    }

    final rows = await db.query(
      Db.synthCache,
      where: '${Db.synthBookId} = ? AND ${Db.synthVoiceId} = ? '
          'AND ${Db.synthUnitIndex} = ?',
      whereArgs: <Object?>[1, 'reginald', 0],
    );
    expect(rows, hasLength(2));
    expect(
      rows.map((r) => r[Db.synthProfileId]).toSet(),
      <String>{'sherpa-profile-id', 'raven-profile-id'},
    );
  });
}
