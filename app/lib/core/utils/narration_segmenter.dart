/// A single chunk of text sized for one synthesis pass, tagged with the
/// paragraph it came from so the reader and the (later) narration player share
/// one position model.
class NarrationUnit {
  const NarrationUnit({
    required this.index,
    required this.paragraphIndex,
    required this.text,
  });

  /// Zero-based position of this unit in the ordered unit list for the book.
  final int index;

  /// Zero-based index of the source paragraph this unit belongs to.
  final int paragraphIndex;

  /// The unit's text (one to a few sentences).
  final String text;

  @override
  bool operator ==(Object other) =>
      other is NarrationUnit &&
      other.index == index &&
      other.paragraphIndex == paragraphIndex &&
      other.text == text;

  @override
  int get hashCode => Object.hash(index, paragraphIndex, text);

  @override
  String toString() =>
      'NarrationUnit(index: $index, paragraphIndex: $paragraphIndex, '
      'text: "$text")';
}

/// Splits cleaned book text into ordered [NarrationUnit]s.
///
/// The algorithm is: paragraph (blank-line runs) → sentences (terminal `. ! ?`
/// with an abbreviation guard) → merge short sentences and hard-cap unit length
/// so each unit synthesises in a single pass. Units never span paragraphs, so
/// every unit maps to exactly one `paragraphIndex`.
class NarrationSegmenter {
  const NarrationSegmenter({this.maxUnitChars = 300, this.maxSentences = 3});

  /// Soft cap on a unit's length; a unit is flushed before exceeding it.
  final int maxUnitChars;

  /// Maximum sentences merged into one unit.
  final int maxSentences;

  /// Abbreviations whose trailing period must not end a sentence.
  static const Set<String> _abbreviations = <String>{
    'mr',
    'mrs',
    'ms',
    'dr',
    'st',
    'prof',
    'sr',
    'jr',
    'vs',
    'etc',
    'mt',
    'rev',
    'hon',
    'capt',
    'col',
    'gen',
    'lt',
    'sgt',
    'no',
    'fig',
    'vol',
    'esq',
    'inc',
    'ltd',
    'co',
    'jan',
    'feb',
    'mar',
    'apr',
    'jun',
    'jul',
    'aug',
    'sep',
    'sept',
    'oct',
    'nov',
    'dec',
  };

  static final RegExp _lastWord = RegExp(r'([A-Za-z]+)$');

  /// Segments [paragraphs] (already split by [TextCleanerService]) into units.
  List<NarrationUnit> segmentParagraphs(List<String> paragraphs) {
    final units = <NarrationUnit>[];
    var unitIndex = 0;
    for (var p = 0; p < paragraphs.length; p++) {
      final sentences = _splitSentences(paragraphs[p]);
      for (final chunk in _chunkSentences(sentences)) {
        units.add(
          NarrationUnit(index: unitIndex++, paragraphIndex: p, text: chunk),
        );
      }
    }
    return units;
  }

  List<String> _splitSentences(String paragraph) {
    final sentences = <String>[];
    final buffer = StringBuffer();
    final length = paragraph.length;

    for (var i = 0; i < length; i++) {
      final ch = paragraph[i];
      buffer.write(ch);
      if (ch != '.' && ch != '!' && ch != '?') continue;

      // Absorb trailing closing quotes/brackets into this sentence.
      var j = i + 1;
      while (j < length && _isCloser(paragraph[j])) {
        buffer.write(paragraph[j]);
        j++;
      }

      final atEnd = j >= length;
      final boundary = atEnd || _isWhitespace(paragraph[j]);
      if (boundary &&
          !(ch == '.' && _endsWithAbbreviation(buffer.toString()))) {
        sentences.add(buffer.toString().trim());
        buffer.clear();
      }
      i = j - 1;
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) sentences.add(tail);
    return sentences;
  }

  List<String> _chunkSentences(List<String> sentences) {
    final units = <String>[];
    final buffer = StringBuffer();
    var sentenceCount = 0;

    void flush() {
      final unit = buffer.toString().trim();
      if (unit.isNotEmpty) units.add(unit);
      buffer.clear();
      sentenceCount = 0;
    }

    for (final sentence in sentences) {
      final prospectiveLength = buffer.length + sentence.length + 1;
      if (buffer.isNotEmpty &&
          (sentenceCount >= maxSentences || prospectiveLength > maxUnitChars)) {
        flush();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
      sentenceCount++;
      // A single sentence longer than the cap becomes its own unit.
      if (buffer.length >= maxUnitChars) flush();
    }
    flush();
    return units;
  }

  bool _endsWithAbbreviation(String sentence) {
    final trimmed = sentence.trimRight();
    if (!trimmed.endsWith('.')) return false;
    final withoutDot = trimmed.substring(0, trimmed.length - 1);
    final match = _lastWord.firstMatch(withoutDot);
    if (match == null) return false;
    final word = match.group(1)!;
    if (word.length == 1 && word == word.toUpperCase()) return true;
    return _abbreviations.contains(word.toLowerCase());
  }

  bool _isCloser(String ch) =>
      ch == '"' ||
      ch == "'" ||
      ch == ')' ||
      ch == ']' ||
      ch == '\u201D' ||
      ch == '\u2019';

  bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}
