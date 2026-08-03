import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/design/operational_text_theme.dart';
import 'package:codex_bridge_mobile/main.dart';

void main() {
  testWidgets('shows the Codex Bridge Mobile landing screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CodexBridgeMobileApp());

    expect(find.text('Codex Bridge Mobile'), findsOneWidget);
    expect(find.text('Terminal móvel'), findsOneWidget);
    expect(find.text('codex bridge mobile'), findsOneWidget);
    expect(find.text('[ready] Local foundation active'), findsOneWidget);
  });

  test('provides Material 3 themes for light and dark system settings', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();

    expect(lightTheme.useMaterial3, isTrue);
    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.extension<OperationalTextTheme>()?.metadata, isNotNull);
    expect(
      lightTheme.extension<OperationalTextTheme>()?.code.fontFamily,
      'monospace',
    );
    expect(
      lightTheme.extension<OperationalTextTheme>()?.log.fontFamily,
      'monospace',
    );
  });
}
