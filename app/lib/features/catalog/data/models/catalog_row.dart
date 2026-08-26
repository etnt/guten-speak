/// A lightweight, isolate-sendable catalog record parsed from Project
/// Gutenberg's `pg_catalog.csv`. Contains only plain fields so it can be
/// returned from a background parsing isolate via `compute`.
class CatalogRow {
  const CatalogRow({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.subjects,
  });

  /// Project Gutenberg id (the CSV `Text#` column).
  final int id;
  final String title;

  /// Raw `Authors` field, e.g. `Austen, Jane, 1775-1817; Someone Else`.
  final String author;

  /// Raw `Language` field, e.g. `en` (occasionally `; `-separated).
  final String language;

  /// Raw `Subjects` field, `; `-separated.
  final String subjects;
}
