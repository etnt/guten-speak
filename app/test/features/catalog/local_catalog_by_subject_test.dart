import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/storage/app_database.dart';
import 'package:guten_speak/features/catalog/data/datasources/local_catalog_data_source.dart';
import 'package:guten_speak/features/catalog/data/models/catalog_row.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalCatalogDataSource dataSource;
  late Database db;

  Future<void> insertCatalog() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE ${Db.catalog} (
        ${Db.catId} INTEGER PRIMARY KEY,
        ${Db.catTitle} TEXT NOT NULL,
        ${Db.catAuthor} TEXT NOT NULL,
        ${Db.catTitleLc} TEXT NOT NULL,
        ${Db.catAuthorLc} TEXT NOT NULL,
        ${Db.catLanguage} TEXT NOT NULL,
        ${Db.catSubjects} TEXT NOT NULL
      )
    ''');
    dataSource = LocalCatalogDataSource(db);
    await dataSource.replaceAll(const [
      CatalogRow(
        id: 1342,
        title: 'Pride and Prejudice',
        author: 'Austen, Jane, 1775-1817',
        language: 'en',
        subjects: 'Fiction; Romance; England -- Social life',
      ),
      CatalogRow(
        id: 84,
        title: 'Frankenstein',
        author: 'Shelley, Mary Wollstonecraft',
        language: 'en',
        subjects: 'Science Fiction; Gothic Fiction; Monsters',
      ),
      CatalogRow(
        id: 11,
        title: 'Alice in Wonderland',
        author: 'Carroll, Lewis',
        language: 'en',
        subjects: 'Fantasy; Adventure stories',
      ),
      CatalogRow(
        id: 76,
        title: 'Adventures of Huckleberry Finn',
        author: 'Twain, Mark',
        language: 'en',
        subjects: 'Adventure fiction; Mississippi River',
      ),
      CatalogRow(
        id: 100,
        title: 'Siddhartha',
        author: 'Hesse, Hermann',
        language: 'de',
        subjects: 'German literature; Philosophy',
      ),
    ]);
  }

  setUp(insertCatalog);

  tearDown(() async {
    await db.close();
  });

  test('matches subjects case-insensitively, ordered by id', () async {
    final books = await dataSource.bySubject('fiction');
    expect(books.map((b) => b.id), [76, 84, 1342]);
  });

  test('matches multi-word subjects', () async {
    final books = await dataSource.bySubject('Science Fiction');
    expect(books.map((b) => b.id), [84]);
  });

  test('respects the limit', () async {
    final books = await dataSource.bySubject('fiction', limit: 1);
    expect(books.map((b) => b.id), [76]);
  });

  test('returns no rows for an unknown subject', () async {
    expect(await dataSource.bySubject('Cookbook'), isEmpty);
  });

  test('treats LIKE wildcards in the subject literally', () async {
    // Unescaped, '%' would widen the match to every fiction book; escaped it
    // must match the literal string, which no subject contains.
    expect(await dataSource.bySubject('Fiction%'), isEmpty);
  });

  test('rows map to readable book summaries', () async {
    final books = await dataSource.bySubject('Science Fiction');
    expect(books.single.title, 'Frankenstein');
    expect(books.single.authorNames, 'Shelley, Mary Wollstonecraft');
    expect(books.single.plainTextUrl, contains('ebooks/84.txt'));
    expect(books.single.coverImageUrl, isNotNull);
  });
}
