import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/utils/toc_extractor.dart';

void main() {
  const extractor = TocExtractor();

  group('TocExtractor.extract', () {
    test('detects keyword headings with roman and arabic numerals', () {
      final entries = extractor.extract(<String>[
        'CHAPTER I',
        'It was the best of times, it was the worst of times.',
        'Chapter 2',
        'More prose that continues the story for a while.',
      ]);

      expect(entries.length, 2);
      expect(entries[0].title, 'CHAPTER I');
      expect(entries[0].paragraphIndex, 0);
      expect(entries[1].title, 'Chapter 2');
      expect(entries[1].paragraphIndex, 2);
    });

    test('detects bare numerals as headings', () {
      final entries = extractor.extract(<String>['IV', 'Some body text here.']);

      expect(entries.single.title, 'IV');
      expect(entries.single.paragraphIndex, 0);
    });

    test('recognises other structural keywords', () {
      final entries = extractor.extract(<String>[
        'BOOK THE FIRST',
        'Prose that opens the first book and runs on for a sentence.',
        'PART II',
        'Prose paragraph that is clearly not a heading at all.',
      ]);

      expect(entries.map((e) => e.title).toList(), <String>[
        'BOOK THE FIRST',
        'PART II',
      ]);
    });

    test('ignores a printed contents page and points at real chapters', () {
      final entries = extractor.extract(<String>[
        'CONTENTS',
        'CHAPTER 1. Loomings.',
        'CHAPTER 2. The Carpet-Bag.',
        'CHAPTER 3. The Spouter-Inn.',
        'ETYMOLOGY.',
        'CHAPTER 1. Loomings.',
        'Call me Ishmael. Some years ago—never mind how long precisely.',
        'CHAPTER 2. The Carpet-Bag.',
        'I stuffed a shirt or two into my old carpet-bag.',
      ]);

      expect(entries, <TocEntry>[
        const TocEntry(title: 'CHAPTER 1. Loomings.', paragraphIndex: 5),
        const TocEntry(title: 'CHAPTER 2. The Carpet-Bag.', paragraphIndex: 7),
      ]);
    });

    test('ignores long paragraphs that merely start with a keyword', () {
      final entries = extractor.extract(<String>[
        'Chapter and verse were quoted at length throughout the sermon, '
            'which went on for what felt like an eternity to the congregation.',
      ]);

      expect(entries, isEmpty);
    });

    test('returns empty for a book with no detectable headings', () {
      final entries = extractor.extract(<String>[
        'Just a paragraph.',
        'Another paragraph.',
      ]);

      expect(entries, isEmpty);
    });

    test('returns empty for empty input', () {
      expect(extractor.extract(const <String>[]), isEmpty);
    });
  });
}
