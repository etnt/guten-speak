import 'package:flutter_test/flutter_test.dart';

import 'package:guten_speak_poc/main.dart';

void main() {
  testWidgets('App builds and shows the spike screen', (tester) async {
    await tester.pumpWidget(const PocApp());
    expect(find.text('Guten-Speak — Voice Clone Spike'), findsOneWidget);
    expect(find.text('1. Prepare model'), findsOneWidget);
  });
}
