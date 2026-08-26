import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/app/app.dart';

void main() {
  testWidgets('App renders Discover screen as initial destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GutenSpeakApp()));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
