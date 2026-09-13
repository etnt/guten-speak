import 'package:flutter/material.dart';
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

  group('readingCompletionPercentage', () {
    test('returns 0 when paragraph count is empty', () {
      expect(
        readingCompletionPercentage(paragraphIndex: 5, paragraphCount: 0),
        0,
      );
    });

    test('shows 0% at the first paragraph and 100% at the last', () {
      expect(
        readingCompletionPercentage(paragraphIndex: 0, paragraphCount: 100),
        0,
      );
      expect(
        readingCompletionPercentage(paragraphIndex: 99, paragraphCount: 100),
        100,
      );
    });

    test('clamps out-of-range positions', () {
      expect(
        readingCompletionPercentage(paragraphIndex: -4, paragraphCount: 10),
        0,
      );
      expect(
        readingCompletionPercentage(paragraphIndex: 50, paragraphCount: 10),
        100,
      );
    });

    test('rounds to nearest percentage point', () {
      expect(
        readingCompletionPercentage(paragraphIndex: 50, paragraphCount: 201),
        25,
      );
      expect(
        readingCompletionPercentage(paragraphIndex: 1, paragraphCount: 3),
        50,
      );
    });
  });

  group('ReaderProgressLabel', () {
    testWidgets('exposes a clear reading progress semantics value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderProgressLabel(
              paragraphIndex: 24,
              paragraphCount: 100,
              color: Colors.black,
            ),
          ),
        ),
      );

      expect(find.text('25%'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(ReaderProgressLabel));
      expect(
        semantics,
        matchesSemantics(
          label: 'Reading progress',
          value: '25 percent',
        ),
      );
    });

    testWidgets('uses live-region announcements at milestone percentages', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderProgressLabel(
              paragraphIndex: 20,
              paragraphCount: 100,
              color: Colors.black,
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(ReaderProgressLabel));
      expect(
        semantics,
        matchesSemantics(
          label: 'Reading progress',
          value: '20 percent',
        ),
      );
    });
  });

  group('ReadingProgressAnnouncementState', () {
    test('deduplicates already-announced milestones', () {
      final state = ReadingProgressAnnouncementState();

      expect(state.nextMilestoneToAnnounce(9), isNull);
      expect(state.nextMilestoneToAnnounce(10), 10);
      state.markMilestoneAnnounced(10);

      expect(state.nextMilestoneToAnnounce(11), isNull);
      expect(state.nextMilestoneToAnnounce(10), isNull);
      expect(state.nextMilestoneToAnnounce(20), 20);
      state.markMilestoneAnnounced(20);

      expect(state.nextMilestoneToAnnounce(21), isNull);
      expect(state.nextMilestoneToAnnounce(20), isNull);
      expect(state.nextMilestoneToAnnounce(100), 100);
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
