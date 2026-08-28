import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/app/app.dart';

void main() {
  testWidgets('App renders the catalog with start-page navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GutenSpeakApp()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });
}
