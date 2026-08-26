import 'dart:io';

import 'package:csv/csv.dart';

import '../models/catalog_row.dart';

/// Parses a Project Gutenberg `pg_catalog.csv` file into [CatalogRow]s.
///
/// Designed to run in a background isolate via `compute`: it takes the file
/// *path* (not its contents) so the ~20 MB CSV never lives on the UI isolate's
/// heap. Only `Type == 'Text'` entries are kept — audio, image and dataset
/// records are skipped since the app only reads/narrates plain text.
///
/// The CSV has quoted fields containing commas and even embedded newlines
/// (multi-line titles), so a proper RFC-4180 parser is required rather than a
/// line split.
List<CatalogRow> parseCatalogCsvFile(String path) {
  final content = File(path).readAsStringSync().replaceAll('\r\n', '\n');
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(content);

  final result = <CatalogRow>[];
  // Row 0 is the header (`Text#,Type,Issued,Title,Language,Authors,...`).
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length < 7) continue;
    if (row[1] != 'Text') continue;
    final id = int.tryParse(_asString(row[0]).trim());
    if (id == null) continue;
    result.add(
      CatalogRow(
        id: id,
        title: _clean(row[3]),
        language: _clean(row[4]),
        author: _clean(row[5]),
        subjects: _clean(row[6]),
      ),
    );
  }
  return result;
}

String _asString(Object? value) => value as String? ?? '';

/// Flattens embedded newlines (from multi-line quoted fields) into spaces and
/// trims surrounding whitespace.
String _clean(Object? value) =>
    _asString(value).replaceAll('\n', ' ').replaceAll('  ', ' ').trim();
