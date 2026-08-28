import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/library/presentation/providers/library_providers.dart';
import 'package:guten_speak/features/library/presentation/widgets/recently_read_sheet.dart';

void main() {
  testWidgets('shows guidance when no books have been read', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentlyReadBooksProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: RecentlyReadSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recently read'), findsOneWidget);
    expect(find.textContaining('No recently read books yet'), findsOneWidget);
  });
}
