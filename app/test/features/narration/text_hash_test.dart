import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/narration/data/text_hash.dart';

void main() {
  group('stableTextHash', () {
    test('is deterministic for the same input', () {
      const text = 'The quick brown fox jumps over the lazy dog.';
      expect(stableTextHash(text), stableTextHash(text));
    });

    test('differs for different input', () {
      expect(
        stableTextHash('Chapter one.'),
        isNot(stableTextHash('Chapter two.')),
      );
    });

    test('is a 16-character lowercase hex string', () {
      final hash = stableTextHash('anything');
      expect(hash.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
    });

    test('handles empty text', () {
      final hash = stableTextHash('');
      expect(hash.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
    });

    test('handles multibyte characters deterministically', () {
      const text = 'Café — naïve résumé — 日本語';
      expect(stableTextHash(text), stableTextHash(text));
      expect(
        stableTextHash(text),
        isNot(stableTextHash('Cafe - naive resume')),
      );
    });
  });
}
