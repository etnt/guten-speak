/// Strips Project Gutenberg boilerplate from a raw `.txt` download and
/// normalises hard-wrapped lines into clean paragraphs.
///
/// Gutenberg plain-text files wrap the actual book between machine-readable
/// header/footer markers and hard-wrap body text at ~70 columns. This service
/// removes the markers (across the several historical formats) and re-flows the
/// wrapped lines into blank-line-delimited paragraphs suitable for a reflowable
/// reader.
class TextCleanerService {
  const TextCleanerService();

  /// Byte-order mark that sometimes prefixes UTF-8 Gutenberg files.
  static const String _bom = '\uFEFF';

  /// Modern start marker, e.g.
  /// `*** START OF THE PROJECT GUTENBERG EBOOK PRIDE AND PREJUDICE ***`.
  static final RegExp _startMarker = RegExp(
    r'^\*\*\*\s*START OF (?:THE|THIS) PROJECT GUTENBERG.*?\*\*\*\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  /// Modern end marker, e.g.
  /// `*** END OF THE PROJECT GUTENBERG EBOOK ... ***`.
  static final RegExp _endMarker = RegExp(
    r'^\*\*\*\s*END OF (?:THE|THIS) PROJECT GUTENBERG.*?\*\*\*\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  /// Legacy pre-2004 header terminator that precedes the body.
  static final RegExp _legacySmallPrintEnd = RegExp(
    r'\*END\*\s*THE SMALL PRINT!.*$',
    caseSensitive: false,
    multiLine: true,
  );

  /// Legacy footer, e.g. `End of the Project Gutenberg Etext of ...` or
  /// `End of Project Gutenberg's ...`.
  static final RegExp _legacyEnd = RegExp(
    r'^End of (?:the )?Project Gutenberg.*$',
    caseSensitive: false,
    multiLine: true,
  );

  /// Removes boilerplate and returns paragraph-normalised body text.
  ///
  /// Paragraphs are separated by a single blank line; the hard wrapping inside
  /// each paragraph is collapsed to spaces. When no markers are found the whole
  /// input is treated as body text (best-effort for non-standard editions).
  String clean(String raw) {
    var text = raw;
    if (text.startsWith(_bom)) {
      text = text.substring(_bom.length);
    }
    // Normalise line endings so a single `\n` model works everywhere.
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    text = _stripHeader(text);
    text = _stripFooter(text);

    return _reflowParagraphs(text);
  }

  /// Splits already-cleaned text into its ordered paragraphs.
  List<String> paragraphs(String cleaned) {
    if (cleaned.isEmpty) return const <String>[];
    return cleaned.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
  }

  String _stripHeader(String text) {
    final modern = _startMarker.firstMatch(text);
    if (modern != null) {
      return text.substring(modern.end);
    }
    final legacy = _legacySmallPrintEnd.firstMatch(text);
    if (legacy != null) {
      return text.substring(legacy.end);
    }
    return text;
  }

  String _stripFooter(String text) {
    final modern = _endMarker.firstMatch(text);
    if (modern != null) {
      return text.substring(0, modern.start);
    }
    final legacy = _legacyEnd.firstMatch(text);
    if (legacy != null) {
      return text.substring(0, legacy.start);
    }
    return text;
  }

  /// Collapses hard-wrapped lines into paragraphs.
  ///
  /// A blank line (optionally with surrounding whitespace) delimits paragraphs.
  /// Consecutive non-blank lines are joined with a single space. Runs of
  /// multiple blank lines collapse to one paragraph break.
  String _reflowParagraphs(String text) {
    final lines = text.split('\n');
    final paragraphs = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final paragraph = buffer.toString().trim();
      if (paragraph.isNotEmpty) {
        paragraphs.add(paragraph);
      }
      buffer.clear();
    }

    for (final line in lines) {
      if (line.trim().isEmpty) {
        flush();
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line.trim());
      }
    }
    flush();

    return paragraphs.join('\n\n');
  }
}
