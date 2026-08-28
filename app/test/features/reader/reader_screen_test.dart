import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/reader/presentation/screens/reader_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

  group('firstReadableParagraphIndex', () {
    test('ignores trailing padding below a hidden paragraph', () {
      final positions = <ItemPosition>[
        const ItemPosition(
          index: 8,
          itemLeadingEdge: -0.02,
          itemTrailingEdge: 0.12,
        ),
        const ItemPosition(
          index: 9,
          itemLeadingEdge: 0.12,
          itemTrailingEdge: 0.28,
        ),
        const ItemPosition(
          index: 10,
          itemLeadingEdge: 0.28,
          itemTrailingEdge: 0.43,
        ),
      ];

      expect(
        firstReadableParagraphIndex(
          positions,
          topInsetFraction: 0.10,
          itemTrailingPaddingFraction: 0.03,
          fallback: 0,
        ),
        9,
      );
    });

    test(
      'selects visible text crossing the bar regardless of iteration order',
      () {
        final positions = <ItemPosition>[
          const ItemPosition(
            index: 12,
            itemLeadingEdge: 0.31,
            itemTrailingEdge: 0.43,
          ),
          const ItemPosition(
            index: 10,
            itemLeadingEdge: 0.04,
            itemTrailingEdge: 0.18,
          ),
          const ItemPosition(
            index: 11,
            itemLeadingEdge: 0.18,
            itemTrailingEdge: 0.31,
          ),
        ];

        expect(
          firstReadableParagraphIndex(
            positions,
            topInsetFraction: 0.10,
            itemTrailingPaddingFraction: 0.02,
            fallback: 0,
          ),
          10,
        );
      },
    );

    test(
      'uses a tall paragraph crossing the boundary when no start is shown',
      () {
        const tallParagraph = ItemPosition(
          index: 7,
          itemLeadingEdge: -0.20,
          itemTrailingEdge: 0.90,
        );

        expect(
          firstReadableParagraphIndex(
            const <ItemPosition>[tallParagraph],
            topInsetFraction: 0.10,
            itemTrailingPaddingFraction: 0.02,
            fallback: 0,
          ),
          7,
        );
      },
    );

    test('uses the fallback when no paragraph reaches the readable area', () {
      expect(
        firstReadableParagraphIndex(
          const <ItemPosition>[
            ItemPosition(
              index: 4,
              itemLeadingEdge: -0.10,
              itemTrailingEdge: 0.05,
            ),
          ],
          topInsetFraction: 0.10,
          itemTrailingPaddingFraction: 0.02,
          fallback: 3,
        ),
        3,
      );
    });
  });
}
