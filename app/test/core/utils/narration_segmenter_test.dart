import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/utils/narration_segmenter.dart';

void main() {
  group('NarrationSegmenter.segmentParagraphs', () {
    test('merges short sentences up to the sentence cap', () {
      const segmenter = NarrationSegmenter();
      final units = segmenter.segmentParagraphs(<String>[
        'One. Two. Three. Four.',
      ]);

      expect(units.length, 2);
      expect(units[0].text, 'One. Two. Three.');
      expect(units[1].text, 'Four.');
    });

    test('does not split on common abbreviations', () {
      const segmenter = NarrationSegmenter(maxSentences: 1);
      final units = segmenter.segmentParagraphs(<String>[
        'Mr. Bennet went home.',
      ]);

      expect(units.length, 1);
      expect(units.single.text, 'Mr. Bennet went home.');
    });

    test('does not split on single-capital initials', () {
      const segmenter = NarrationSegmenter(maxSentences: 1);
      final units = segmenter.segmentParagraphs(<String>[
        'J. R. R. Tolkien wrote this.',
      ]);

      expect(units.length, 1);
    });

    test('splits genuine sentence boundaries', () {
      const segmenter = NarrationSegmenter(maxSentences: 1);
      final units = segmenter.segmentParagraphs(<String>[
        'First sentence. Second sentence!',
      ]);

      expect(units.map((u) => u.text).toList(), <String>[
        'First sentence.',
        'Second sentence!',
      ]);
    });

    test('absorbs closing quotes into the sentence', () {
      const segmenter = NarrationSegmenter(maxSentences: 1);
      final units = segmenter.segmentParagraphs(<String>['"Stop!" He left.']);

      expect(units.first.text, '"Stop!"');
      expect(units.last.text, 'He left.');
    });

    test('emits an over-long single sentence as its own unit', () {
      const segmenter = NarrationSegmenter(maxUnitChars: 20);
      final units = segmenter.segmentParagraphs(<String>[
        'This one sentence is definitely longer than twenty characters.',
      ]);

      expect(units.length, 1);
    });

    test('never spans paragraphs and tags the source paragraph', () {
      const segmenter = NarrationSegmenter();
      final units = segmenter.segmentParagraphs(<String>[
        'Paragraph zero.',
        'Paragraph one.',
      ]);

      expect(units.length, 2);
      expect(units[0].paragraphIndex, 0);
      expect(units[1].paragraphIndex, 1);
      expect(units[0].index, 0);
      expect(units[1].index, 1);
    });

    test('returns no units for empty input', () {
      const segmenter = NarrationSegmenter();
      expect(segmenter.segmentParagraphs(const <String>[]), isEmpty);
    });

    test('drops decorative dividers and keeps unit indices contiguous', () {
      const segmenter = NarrationSegmenter();
      final units = segmenter.segmentParagraphs(<String>[
        'Before the break.',
        '* * * * * *',
        '----',
        'After the break.',
      ]);

      expect(units.map((u) => u.text).toList(), <String>[
        'Before the break.',
        'After the break.',
      ]);
      expect(units[0].index, 0);
      expect(units[1].index, 1);
      expect(units[1].paragraphIndex, 3);
    });
  });
}
