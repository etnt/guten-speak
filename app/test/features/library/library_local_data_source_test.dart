import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/storage/app_database.dart';
import 'package:guten_speak/features/library/data/datasources/library_local_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabase extends Mock implements Database {}

void main() {
  test('recent books query uses reading activity order and limit', () async {
    final database = _MockDatabase();
    final rows = <Map<String, Object?>>[
      _bookRow(id: 2, title: 'Most recent'),
      _bookRow(id: 1, title: 'Earlier'),
    ];
    when(() => database.rawQuery(any(), any())).thenAnswer((_) async => rows);

    final books = await LibraryLocalDataSource(
      database,
    ).getRecentlyReadBooks(limit: 2);

    expect(books.map((book) => book.title), ['Most recent', 'Earlier']);
    final captured = verify(
      () => database.rawQuery(captureAny(), captureAny()),
    ).captured;
    expect(captured.first, contains('INNER JOIN ${Db.progress}'));
    expect(
      captured.first,
      contains('ORDER BY progress.${Db.progressUpdatedAt} DESC'),
    );
    expect(captured.last, <Object?>[2]);
  });
}

Map<String, Object?> _bookRow({required int id, required String title}) => {
  Db.bookId: id,
  Db.bookTitle: title,
  Db.bookAuthor: 'Author $id',
  Db.bookPath: '/books/$id/book.epub',
  Db.bookLanguage: 'en',
  Db.bookCoverUrl: null,
  Db.bookDownloadedAt: id,
};
