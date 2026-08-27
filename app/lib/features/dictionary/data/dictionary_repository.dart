import 'package:sqflite/sqflite.dart';

import '../domain/entities/dictionary_entry.dart';

/// Reads word definitions from the downloaded WordNet SQLite database.
///
/// The database has a single `senses(word, pos, definition, examples, synonyms)`
/// table (see `tools/build_wordnet_db.py`), with `word` stored lowercased and
/// `examples`/`synonyms` newline-joined.
class DictionaryRepository {
  DictionaryRepository(this._db);

  final Database _db;

  /// Looks up [word], trying a few naive morphological fall-backs (possessive,
  /// plural, and common verb inflections) so inflected forms in the text still
  /// resolve to their WordNet lemma. Returns an empty list when nothing matches.
  Future<List<DictionarySense>> lookup(String word) async {
    for (final candidate in _candidates(word)) {
      final rows = await _db.query(
        'senses',
        columns: ['pos', 'definition', 'examples', 'synonyms'],
        where: 'word = ?',
        whereArgs: [candidate],
        orderBy:
            'CASE pos '
            "WHEN 'n' THEN 0 "
            "WHEN 'v' THEN 1 "
            "WHEN 'a' THEN 2 "
            "WHEN 's' THEN 2 "
            "WHEN 'r' THEN 3 "
            'ELSE 4 END',
      );
      if (rows.isNotEmpty) {
        return rows.map(_fromRow).toList(growable: false);
      }
    }
    return const [];
  }

  DictionarySense _fromRow(Map<String, Object?> row) => DictionarySense(
    pos: (row['pos'] as String?) ?? '',
    definition: (row['definition'] as String?) ?? '',
    examples: _split(row['examples'] as String?),
    synonyms: _split(row['synonyms'] as String?),
  );

  List<String> _split(String? value) {
    if (value == null || value.isEmpty) return const [];
    return value
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// The ordered, de-duplicated set of lemmas to try for [word].
  List<String> _candidates(String word) {
    final w = word.toLowerCase();
    final out = <String>[w];

    void add(String candidate) {
      if (candidate.length >= 2 && !out.contains(candidate)) out.add(candidate);
    }

    if (w.endsWith("'s")) add(w.substring(0, w.length - 2));
    if (w.endsWith('ies') && w.length > 4) {
      add('${w.substring(0, w.length - 3)}y');
    }
    if (w.endsWith('es') && w.length > 3) add(w.substring(0, w.length - 2));
    if (w.endsWith('s') && w.length > 3) add(w.substring(0, w.length - 1));
    if (w.endsWith('ed') && w.length > 3) {
      add(w.substring(0, w.length - 2));
      add(w.substring(0, w.length - 1));
    }
    if (w.endsWith('ing') && w.length > 4) {
      add(w.substring(0, w.length - 3));
      add('${w.substring(0, w.length - 3)}e');
    }
    return out;
  }
}
