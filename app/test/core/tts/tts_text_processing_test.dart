import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/tts_text_processing.dart';

void main() {
  group('normalizeTtsText', () {
    test('drops straight and curly double quotes entirely', () {
      expect(
        normalizeTtsText('He said "hello" to \u201Ceveryone\u201D there.'),
        'He said hello to everyone there.',
      );
      expect(normalizeTtsText('low\u201Ehigh\u201Fmarks'), 'lowhighmarks');
    });

    test('folds curly single quotes to a plain apostrophe', () {
      expect(
        normalizeTtsText('it\u2019s the \u2018best\u2019 one'),
        "it's the 'best' one",
      );
    });

    test('leaves already-plain text unchanged', () {
      expect(normalizeTtsText("it's a plain line."), "it's a plain line.");
    });
  });

  group('plausibleAudioSeconds', () {
    test('grows with phrase length off a fixed floor', () {
      expect(plausibleAudioSeconds(''), 4.0);
      expect(plausibleAudioSeconds('a' * 100), 14.0);
    });
  });

  group('splitTtsRetryPhrases', () {
    test('returns the whole string when under the cap', () {
      expect(splitTtsRetryPhrases('short phrase'), <String>['short phrase']);
    });

    test('prefers clause punctuation as a cut point', () {
      const text =
          'This is the first clause of the sentence, and here is a second one '
          'that keeps going well past the limit.';
      final parts = splitTtsRetryPhrases(text, maxChars: 40);
      expect(parts.length, greaterThan(1));
      // The first cut should land right after the comma clause boundary.
      expect(parts.first.endsWith('sentence,'), isTrue);
      // No fragment exceeds a reasonable multiple of the cap.
      for (final part in parts) {
        expect(part.length, lessThanOrEqualTo(60));
      }
    });

    test('falls back to whitespace when no clause punctuation is near', () {
      final text = 'word ' * 40; // no clause punctuation at all
      final parts = splitTtsRetryPhrases(text.trim(), maxChars: 30);
      expect(parts.length, greaterThan(1));
      for (final part in parts) {
        expect(part.contains('  '), isFalse);
      }
      // Rejoining the words recovers the original token sequence.
      expect(parts.join(' ').split(' ').length, 40);
    });

    test('never loses characters across the split (word-preserving)', () {
      const text =
          'Alpha, beta; gamma: delta epsilon zeta eta theta iota kappa lambda '
          'mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega.';
      final parts = splitTtsRetryPhrases(text, maxChars: 50);
      final rejoinedWords = parts
          .expand((p) => p.split(RegExp(r'\s+')))
          .where((w) => w.isNotEmpty);
      final originalWords = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty);
      expect(rejoinedWords.length, originalWords.length);
    });
  });
}
