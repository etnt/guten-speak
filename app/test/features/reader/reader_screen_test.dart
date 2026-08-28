import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/reader/presentation/screens/reader_screen.dart';

void main() {
  group('compactReaderTitle', () {
    test('leaves titles of 15 characters or fewer unchanged', () {
      expect(compactReaderTitle('Short title'), 'Short title');
      expect(compactReaderTitle('123456789012345'), '123456789012345');
    });

    test('keeps the first 15 characters and appends an ellipsis', () {
      expect(compactReaderTitle('1234567890123456'), '123456789012345…');
    });

    test('does not split supplementary Unicode characters', () {
      final title = List.filled(16, '📚').join();
      expect(compactReaderTitle(title), '${List.filled(15, '📚').join()}…');
    });
  });
}
