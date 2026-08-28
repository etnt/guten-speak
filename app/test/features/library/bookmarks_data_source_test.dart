import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/storage/app_database.dart';
import 'package:guten_speak/features/library/data/datasources/library_local_data_source.dart';
import 'package:guten_speak/features/library/domain/entities/bookmark.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabase extends Mock implements Database {}

void main() {
  test('getBookmarks filters by book and orders by paragraph index', () async {
    final database = _MockDatabase();
    when(
      () => database.query(
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
      ),
    ).thenAnswer(
      (_) async => <Map<String, Object?>>[
        _bookmarkRow(id: 1, paragraphIndex: 3, note: 'A note'),
        _bookmarkRow(id: 2, paragraphIndex: 9),
      ],
    );

    final bookmarks = await LibraryLocalDataSource(database).getBookmarks(7);

    expect(bookmarks.map((b) => b.paragraphIndex), [3, 9]);
    expect(bookmarks.first.note, 'A note');
    expect(bookmarks.last.note, isNull);
    final captured = verify(
      () => database.query(
        captureAny(),
        where: captureAny(named: 'where'),
        whereArgs: captureAny(named: 'whereArgs'),
        orderBy: captureAny(named: 'orderBy'),
      ),
    ).captured;
    expect(captured[0], Db.bookmarks);
    expect(captured[1], '${Db.bookmarkBookId} = ?');
    expect(captured[2], <Object?>[7]);
    expect(captured[3], '${Db.bookmarkParagraphIndex} ASC');
  });

  test('addBookmark inserts and returns the row with its new id', () async {
    final database = _MockDatabase();
    when(() => database.insert(any(), any())).thenAnswer((_) async => 42);

    final saved = await LibraryLocalDataSource(database).addBookmark(
      Bookmark(
        bookId: 7,
        paragraphIndex: 5,
        note: 'Here',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );

    expect(saved.id, 42);
    final captured = verify(
      () => database.insert(captureAny(), captureAny()),
    ).captured;
    expect(captured[0], Db.bookmarks);
    final values = captured[1] as Map<String, Object?>;
    expect(values[Db.bookmarkBookId], 7);
    expect(values[Db.bookmarkParagraphIndex], 5);
    expect(values[Db.bookmarkNote], 'Here');
    expect(values[Db.bookmarkCreatedAt], 1000);
  });

  test('deleteBookmark deletes by row id', () async {
    final database = _MockDatabase();
    when(
      () => database.delete(
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);

    await LibraryLocalDataSource(database).deleteBookmark(42);

    final captured = verify(
      () => database.delete(
        captureAny(),
        where: captureAny(named: 'where'),
        whereArgs: captureAny(named: 'whereArgs'),
      ),
    ).captured;
    expect(captured[0], Db.bookmarks);
    expect(captured[1], '${Db.bookmarkId} = ?');
    expect(captured[2], <Object?>[42]);
  });
}

Map<String, Object?> _bookmarkRow({
  required int id,
  required int paragraphIndex,
  String? note,
}) => {
  Db.bookmarkId: id,
  Db.bookmarkBookId: 7,
  Db.bookmarkParagraphIndex: paragraphIndex,
  Db.bookmarkNote: note,
  Db.bookmarkCreatedAt: id,
};
