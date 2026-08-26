/// A detected chapter heading pointing at the paragraph where it starts.
class TocEntry {
  const TocEntry({required this.title, required this.paragraphIndex});

  /// The heading text as it appears in the book (e.g. `CHAPTER IV`).
  final String title;

  /// Index into the book's paragraph list where this heading appears.
  final int paragraphIndex;

  @override
  bool operator ==(Object other) =>
      other is TocEntry &&
      other.title == title &&
      other.paragraphIndex == paragraphIndex;

  @override
  int get hashCode => Object.hash(title, paragraphIndex);

  @override
  String toString() => 'TocEntry("$title" @ $paragraphIndex)';
}

/// Best-effort table-of-contents extraction from cleaned plain text.
///
/// Gutenberg texts have no structural markup, so headings are detected
/// heuristically: short, blank-line-delimited paragraphs that either start with
/// a structural keyword (`CHAPTER`, `BOOK`, `PART`, …) followed by a roman or
/// arabic numeral, or are a bare roman/arabic numeral. When nothing matches the
/// result is empty and the reader degrades to "no chapters".
class TocExtractor {
  const TocExtractor({this.maxHeadingLength = 80});

  /// Paragraphs longer than this are never treated as headings.
  final int maxHeadingLength;

  static final RegExp _keywordHeading = RegExp(
    r'^(?:chapter|book|part|volume|section|canto|letter|act|scene)\b'
    r'[\s.\-\u2014:]*(?:[ivxlcdm]+|\d+)?',
    caseSensitive: false,
  );

  static final RegExp _bareNumeral = RegExp(
    r'^(?:[ivxlcdm]+|\d+)[.\u3002]?$',
    caseSensitive: false,
  );

  /// Extracts headings from [paragraphs] (as produced by `TextCleanerService`).
  ///
  /// A heading only counts as a real chapter start when it is surrounded by
  /// prose. Gutenberg books often open with a printed "CONTENTS" page — a run of
  /// consecutive chapter-title lines — which would otherwise produce entries that
  /// point at the contents list instead of the actual chapters. Requiring that
  /// neither neighbouring paragraph is itself a heading drops that whole block
  /// (each contents entry has another heading as a neighbour) while keeping the
  /// real chapter starts (each preceded and followed by body text).
  List<TocEntry> extract(List<String> paragraphs) {
    final flags = <bool>[
      for (var i = 0; i < paragraphs.length; i++)
        _isHeading(paragraphs[i].trim()),
    ];

    final entries = <TocEntry>[];
    for (var i = 0; i < paragraphs.length; i++) {
      if (!flags[i]) continue;
      final prevIsHeading = i > 0 && flags[i - 1];
      final nextIsHeading = i + 1 < flags.length && flags[i + 1];
      if (prevIsHeading || nextIsHeading) continue;
      entries.add(TocEntry(title: paragraphs[i].trim(), paragraphIndex: i));
    }
    return entries;
  }

  bool _isHeading(String paragraph) {
    if (paragraph.isEmpty || paragraph.length > maxHeadingLength) return false;
    // A heading is a single short line — reject anything that reads as prose.
    if (paragraph.contains('\n')) return false;
    if (_keywordHeading.hasMatch(paragraph)) return true;
    if (_bareNumeral.hasMatch(paragraph)) return true;
    return false;
  }
}
