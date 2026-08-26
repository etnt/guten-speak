import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'app_database.g.dart';

/// Schema and table/column names for the local metadata database.
///
/// The database stores only lightweight metadata — downloaded book records and
/// reading progress. Book text lives on disk (see the library download path),
/// not in SQLite.
abstract final class Db {
  static const String fileName = 'guten_speak.db';
  static const int version = 2;

  // catalog (local search index of pg_catalog.csv) ---------------------
  static const String catalog = 'catalog';
  static const String catId = 'id';
  static const String catTitle = 'title';
  static const String catAuthor = 'author';
  static const String catTitleLc = 'title_lc';
  static const String catAuthorLc = 'author_lc';
  static const String catLanguage = 'language';
  static const String catSubjects = 'subjects';

  // catalog_meta (key/value: import timestamp, source last-modified) -----
  static const String catalogMeta = 'catalog_meta';
  static const String catalogMetaKey = 'key';
  static const String catalogMetaValue = 'value';

  // books ---------------------------------------------------------------
  static const String books = 'books';
  static const String bookId = 'id';
  static const String bookTitle = 'title';
  static const String bookAuthor = 'author';
  static const String bookPath = 'path';
  static const String bookLanguage = 'language';
  static const String bookCoverUrl = 'cover_url';
  static const String bookDownloadedAt = 'downloaded_at';

  // reading_progress ----------------------------------------------------
  static const String progress = 'reading_progress';
  static const String progressBookId = 'book_id';
  static const String progressParagraphIndex = 'paragraph_index';
  static const String progressUpdatedAt = 'updated_at';
}

/// Opens (creating on first run) the shared metadata database and keeps it open
/// for the app's lifetime.
@Riverpod(keepAlive: true)
Future<Database> appDatabase(Ref ref) async {
  final databasesPath = await getDatabasesPath();
  final path = p.join(databasesPath, Db.fileName);

  final database = await openDatabase(
    path,
    version: Db.version,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  ref.onDispose(database.close);
  return database;
}

Future<void> _onCreate(Database db, int version) async {
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
    CREATE TABLE ${Db.progress} (
      ${Db.progressBookId} INTEGER PRIMARY KEY
        REFERENCES ${Db.books} (${Db.bookId}) ON DELETE CASCADE,
      ${Db.progressParagraphIndex} INTEGER NOT NULL,
      ${Db.progressUpdatedAt} INTEGER NOT NULL
    )
  ''');

  await _createCatalogTables(db);
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await _createCatalogTables(db);
  }
}

/// Creates the local catalog search table and its metadata table. Uses a plain
/// table (not FTS) because the SQLite build bundled with Android does not
/// include the FTS5 module. Search runs as a case-insensitive `LIKE` over the
/// pre-lowercased title/author columns, which is fast enough for the ~80k rows.
Future<void> _createCatalogTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Db.catalog} (
      ${Db.catId} INTEGER PRIMARY KEY,
      ${Db.catTitle} TEXT NOT NULL,
      ${Db.catAuthor} TEXT NOT NULL,
      ${Db.catTitleLc} TEXT NOT NULL,
      ${Db.catAuthorLc} TEXT NOT NULL,
      ${Db.catLanguage} TEXT NOT NULL,
      ${Db.catSubjects} TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Db.catalogMeta} (
      ${Db.catalogMetaKey} TEXT PRIMARY KEY,
      ${Db.catalogMetaValue} TEXT
    )
  ''');
}
