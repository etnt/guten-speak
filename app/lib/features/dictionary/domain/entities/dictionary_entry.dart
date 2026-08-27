/// A single dictionary sense of a word: its part of speech, definition, and
/// optional example sentences and synonyms.
class DictionarySense {
  const DictionarySense({
    required this.pos,
    required this.definition,
    this.examples = const [],
    this.synonyms = const [],
  });

  /// Raw WordNet part-of-speech code: `n`, `v`, `a`, `s` (adjective satellite),
  /// or `r`.
  final String pos;
  final String definition;
  final List<String> examples;
  final List<String> synonyms;

  /// A human-readable part of speech for display.
  String get posLabel {
    switch (pos) {
      case 'n':
        return 'noun';
      case 'v':
        return 'verb';
      case 'a':
      case 's':
        return 'adjective';
      case 'r':
        return 'adverb';
      default:
        return pos;
    }
  }
}
