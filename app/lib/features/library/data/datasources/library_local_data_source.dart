import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/app_database.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/library_book.dart';
import '../../domain/entities/reading_progress.dart';

/// Reads and writes library metadata (downloaded books + reading progress) in
/// the local SQLite database. Throws raw [DatabaseException]s on failure; the
/// repository maps those to typed failures.
class LibraryLocalDataSource {
  const LibraryLocalDataSource(this._db);

  final Database _db;

  Future<void> upsertBook(LibraryBook book) async {
    await _db.insert(Db.books, {
      Db.bookId: book.id,
      Db.bookTitle: book.title,
      Db.bookAuthor: book.author,
      Db.bookPath: book.path,
      Db.bookLanguage: book.language,
      Db.bookCoverUrl: book.coverUrl,
      Db.bookDownloadedAt: book.downloadedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LibraryBook>> getBooks() async {
    final rows = await _db.query(
      Db.books,
      orderBy: '${Db.bookDownloadedAt} DESC',
    );
    return rows.map(_bookFromRow).toList();
  }

  /// Downloaded books that have reading progress, newest read first.
  Future<List<LibraryBook>> getRecentlyReadBooks({int limit = 10}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT books.*
      FROM ${Db.books} AS books
      INNER JOIN ${Db.progress} AS progress
        ON progress.${Db.progressBookId} = books.${Db.bookId}
      ORDER BY progress.${Db.progressUpdatedAt} DESC
      LIMIT ?
      ''',
      <Object?>[limit],
    );
    return rows.map(_bookFromRow).toList();
  }

  Future<LibraryBook?> getBook(int id) async {
    final rows = await _db.query(
      Db.books,
      where: '${Db.bookId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _bookFromRow(rows.first);
  }

  Future<void> deleteBook(int id) async {
    await _db.delete(
      Db.books,
      where: '${Db.bookId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<ReadingProgress?> getProgress(int bookId) async {
    final rows = await _db.query(
      Db.progress,
      where: '${Db.progressBookId} = ?',
      whereArgs: <Object?>[bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ReadingProgress(
      bookId: row[Db.progressBookId]! as int,
      paragraphIndex: row[Db.progressParagraphIndex]! as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row[Db.progressUpdatedAt]! as int,
      ),
    );
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    await _db.insert(Db.progress, {
      Db.progressBookId: progress.bookId,
      Db.progressParagraphIndex: progress.paragraphIndex,
      Db.progressUpdatedAt: progress.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// All bookmarks for [bookId], in reading order (by paragraph index).
  Future<List<Bookmark>> getBookmarks(int bookId) async {
    final rows = await _db.query(
      Db.bookmarks,
      where: '${Db.bookmarkBookId} = ?',
      whereArgs: <Object?>[bookId],
      orderBy: '${Db.bookmarkParagraphIndex} ASC',
    );
    return rows.map(_bookmarkFromRow).toList();
  }

  /// Inserts [bookmark] and returns a copy with the assigned row id.
  Future<Bookmark> addBookmark(Bookmark bookmark) async {
    final id = await _db.insert(Db.bookmarks, {
      Db.bookmarkBookId: bookmark.bookId,
      Db.bookmarkParagraphIndex: bookmark.paragraphIndex,
      Db.bookmarkNote: bookmark.note,
      Db.bookmarkCreatedAt: bookmark.createdAt.millisecondsSinceEpoch,
    });
    return bookmark.copyWith(id: id);
  }

  Future<void> deleteBookmark(int id) async {
    await _db.delete(
      Db.bookmarks,
      where: '${Db.bookmarkId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Bookmark _bookmarkFromRow(Map<String, Object?> row) {
    return Bookmark(
      id: row[Db.bookmarkId]! as int,
      bookId: row[Db.bookmarkBookId]! as int,
      paragraphIndex: row[Db.bookmarkParagraphIndex]! as int,
      note: row[Db.bookmarkNote] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[Db.bookmarkCreatedAt]! as int,
      ),
    );
  }

  LibraryBook _bookFromRow(Map<String, Object?> row) {
    return LibraryBook(
      id: row[Db.bookId]! as int,
      title: row[Db.bookTitle]! as String,
      author: row[Db.bookAuthor]! as String,
      path: row[Db.bookPath]! as String,
      language: row[Db.bookLanguage] as String?,
      coverUrl: row[Db.bookCoverUrl] as String?,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        row[Db.bookDownloadedAt]! as int,
      ),
    );
  }
}
