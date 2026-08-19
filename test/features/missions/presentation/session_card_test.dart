import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #24 extracted `SessionCard` out of `work_screen.dart`'s private
/// `_SessionCard` to reuse it on the project dashboard. Pumps the widget
/// directly rather than through `WorkScreen`, re-pinning the behavior
/// `work_screen_test.dart` already covers indirectly, so a future change to
/// this file fails a focused test first.
void main() {
  LiveSession sessionWith({required String state}) {
    return LiveSession.fromJson(<String, Object?>{
      'id': 's-1',
      'projectId': 'codexbridge',
      'executorId': 'devel3',
      'instruction': 'Do the thing',
      'state': state,
      'priority': 'normal',
      'revision': 1,
      'createdAt': '2026-08-15T12:00:00Z',
    });
  }

  Future<void> pumpCard(WidgetTester tester, LiveSession session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gatewayContextProvider.overrideWith(
            (Ref ref) async => GatewayContext(
              server: Uri.parse('https://bridge.example.com'),
              accessToken: 'access-token',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SessionCard(session: session, busy: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a session awaiting approval carries the intervention label', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, sessionWith(state: 'awaiting_approval'));

    expect(find.text('Needs your approval'), findsOneWidget);
  });

  testWidgets('a running session does not carry the intervention label', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, sessionWith(state: 'running'));

    expect(find.text('Needs your approval'), findsNothing);
  });

  testWidgets('a running session shows a Pause control', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, sessionWith(state: 'running'));

    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
  });

  testWidgets('a paused session shows a Resume control, not Pause', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, sessionWith(state: 'paused'));

    expect(find.widgetWithText(OutlinedButton, 'Resume'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsNothing);
  });
}
