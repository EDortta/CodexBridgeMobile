import 'package:flutter_test/flutter_test.dart';

import 'package:codex_bridge_mobile/main.dart';

void main() {
  testWidgets('shows the Codex Bridge Mobile landing screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CodexBridgeMobileApp());

    expect(find.text('Codex Bridge Mobile'), findsOneWidget);
  });
}
