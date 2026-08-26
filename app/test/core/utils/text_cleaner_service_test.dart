import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/utils/text_cleaner_service.dart';

void main() {
  const cleaner = TextCleanerService();

  group('TextCleanerService.clean', () {
    test('strips BOM, modern markers and reflows hard-wrapped lines', () {
      const raw =
          '\uFEFF'
          'Produced by a volunteer.\r\n'
          'Title: Pride and Prejudice\r\n'
          '*** START OF THE PROJECT GUTENBERG EBOOK PRIDE AND PREJUDICE ***\r\n'
          '\r\n'
          'It is a truth universally\r\n'
          'acknowledged, that a single man.\r\n'
          '\r\n'
          'Second paragraph here\r\n'
          'wrapped across two lines.\r\n'
          '\r\n'
          '*** END OF THE PROJECT GUTENBERG EBOOK PRIDE AND PREJUDICE ***\r\n'
          'This eBook is for the use of anyone anywhere.\r\n';

      final cleaned = cleaner.clean(raw);

      expect(
        cleaned,
        'It is a truth universally acknowledged, that a single man.\n\n'
        'Second paragraph here wrapped across two lines.',
      );
      expect(cleaned.contains('START OF THE PROJECT GUTENBERG'), isFalse);
      expect(cleaned.contains('END OF THE PROJECT GUTENBERG'), isFalse);
      expect(cleaned.contains('volunteer'), isFalse);
      expect(cleaned.contains('use of anyone'), isFalse);
      expect(cleaned.startsWith('\uFEFF'), isFalse);
    });

    test('handles legacy small-print header and legacy footer', () {
      const raw =
          '*END* THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*\n'
          '\n'
          'Real body paragraph one.\n'
          '\n'
          "End of Project Gutenberg's Etext of Something\n";

      final cleaned = cleaner.clean(raw);

      expect(cleaned, 'Real body paragraph one.');
      expect(cleaned.contains('SMALL PRINT'), isFalse);
      expect(cleaned.contains('End of Project Gutenberg'), isFalse);
    });

    test('treats input without markers as body text', () {
      const raw = 'A lone paragraph\nwrapped over lines.\n\nAnother one.';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, 'A lone paragraph wrapped over lines.\n\nAnother one.');
    });

    test('collapses runs of multiple blank lines into one break', () {
      const raw = 'First.\n\n\n\nSecond.';

      expect(cleaner.clean(raw), 'First.\n\nSecond.');
    });
  });

  group('TextCleanerService.paragraphs', () {
    test('splits cleaned text on blank lines and drops empties', () {
      const cleaned = 'One.\n\nTwo.\n\nThree.';

      expect(cleaner.paragraphs(cleaned), <String>['One.', 'Two.', 'Three.']);
    });

    test('returns an empty list for empty input', () {
      expect(cleaner.paragraphs(''), isEmpty);
    });
  });
}
