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
  static const int version = 1;

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
}
