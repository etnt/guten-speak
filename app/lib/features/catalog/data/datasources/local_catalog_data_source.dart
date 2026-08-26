import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/app_database.dart';
import '../models/author.dart';
import '../models/book_summary.dart';
import '../models/catalog_row.dart';

/// Local, offline catalog backed by a plain SQLite table indexing Project
/// Gutenberg's `pg_catalog.csv`. Replaces the flaky Gutendex search/detail
/// calls with instant on-device lookups. Download URLs and cover thumbnails
/// are synthesized from the book id (Project Gutenberg's stable URL scheme),
/// so the CSV alone is enough to read and narrate a book.
///
/// Search is a case-insensitive `LIKE` over pre-lowercased title/author columns
/// — FTS5 isn't used because Android's bundled SQLite omits that module.
class LocalCatalogDataSource {
  const LocalCatalogDataSource(this._db);

  final Database _db;

  static const _columns =
      '${Db.catId}, ${Db.catTitle}, ${Db.catAuthor}, ${Db.catLanguage}, '
      '${Db.catSubjects}';

  /// Number of indexed books.
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT count(*) AS n FROM ${Db.catalog}');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Searches title and author for all query tokens (AND), returning up to
  /// [limit] books ordered by title length (shorter, canonical titles first).
  /// An empty/token-less query yields none.
  Future<List<BookSummary>> search(String query, {int limit = 60}) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const <BookSummary>[];

    const clause = '(${Db.catTitleLc} LIKE ? OR ${Db.catAuthorLc} LIKE ?)';
    final where = List.filled(tokens.length, clause).join(' AND ');
    final args = <Object?>[];
    for (final token in tokens) {
      final like = '%$token%';
      args
        ..add(like)
        ..add(like);
    }
    args.add(limit);

    final rows = await _db.rawQuery(
      'SELECT $_columns FROM ${Db.catalog} WHERE $where '
      'ORDER BY length(${Db.catTitle}) LIMIT ?',
      args,
    );
    return rows.map(_rowToBook).toList(growable: false);
  }

  /// Looks up a single book by its Project Gutenberg id.
  Future<BookSummary?> bookById(int id) async {
    final rows = await _db.rawQuery(
      'SELECT $_columns FROM ${Db.catalog} WHERE ${Db.catId} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return _rowToBook(rows.first);
  }

  /// Replaces the entire catalog index with [rows] in a single transaction,
  /// reporting progress as `(inserted, total)`.
  Future<void> replaceAll(
    List<CatalogRow> rows, {
    void Function(int inserted, int total)? onProgress,
  }) async {
    final total = rows.length;
    await _db.transaction((txn) async {
      await txn.delete(Db.catalog);
      var batch = txn.batch();
      for (var i = 0; i < total; i++) {
        final row = rows[i];
        batch.rawInsert(
          'INSERT INTO ${Db.catalog}'
          '(${Db.catId}, ${Db.catTitle}, ${Db.catAuthor}, ${Db.catTitleLc}, '
          '${Db.catAuthorLc}, ${Db.catLanguage}, ${Db.catSubjects}) '
          'VALUES(?, ?, ?, ?, ?, ?, ?)',
          [
            row.id,
            row.title,
            row.author,
            row.title.toLowerCase(),
            row.author.toLowerCase(),
            row.language,
            row.subjects,
          ],
        );
        if ((i + 1) % 2000 == 0) {
          await batch.commit(noResult: true);
          batch = txn.batch();
          onProgress?.call(i + 1, total);
        }
      }
      await batch.commit(noResult: true);
      onProgress?.call(total, total);
    });
  }

  /// Reads a value from the catalog metadata table.
  Future<String?> metaGet(String key) async {
    final rows = await _db.query(
      Db.catalogMeta,
      columns: [Db.catalogMetaValue],
      where: '${Db.catalogMetaKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[Db.catalogMetaValue] as String?;
  }

  /// Writes a value into the catalog metadata table.
  Future<void> metaSet(String key, String value) async {
    await _db.insert(Db.catalogMeta, <String, Object?>{
      Db.catalogMetaKey: key,
      Db.catalogMetaValue: value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  BookSummary _rowToBook(Map<String, Object?> row) {
    final id = row[Db.catId] as int;
    final title = (row[Db.catTitle] as String?) ?? '';
    final author = (row[Db.catAuthor] as String?) ?? '';
    final language = (row[Db.catLanguage] as String?) ?? '';
    final subjects = (row[Db.catSubjects] as String?) ?? '';
    return BookSummary(
      id: id,
      title: title,
      authors: _parseAuthors(author),
      subjects: _splitList(subjects),
      languages: _splitList(language),
      mediaType: 'Text',
      formats: <String, String>{
        'text/plain; charset=utf-8': AppConstants.plainTextUrl(id),
        'image/jpeg': AppConstants.coverImageUrl(id),
      },
    );
  }

  List<Author> _parseAuthors(String raw) {
    if (raw.trim().isEmpty) return const <Author>[];
    return raw
        .split(';')
        .map((part) => _stripLifeDates(part.trim()))
        .where((name) => name.isNotEmpty)
        .map((name) => Author(name: name))
        .toList(growable: false);
  }

  // Trailing life-span on a name, e.g. "Austen, Jane, 1775-1817".
  static final RegExp _lifeDates = RegExp(r',\s*\d{1,4}\??-\d{0,4}\??$');

  String _stripLifeDates(String name) => name.replaceAll(_lifeDates, '').trim();

  List<String> _splitList(String raw) => raw
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  /// Extracts lowercased alphanumeric tokens from a raw query. Keeping only
  /// alphanumeric runs also strips any `LIKE` wildcards, so the tokens are safe
  /// to interpolate into `%token%` patterns without escaping.
  List<String> _tokenize(String query) =>
      RegExp(r'[\p{L}\p{N}]+', unicode: true)
          .allMatches(query.toLowerCase())
          .map((m) => m.group(0)!)
          .toList(growable: false);
}
