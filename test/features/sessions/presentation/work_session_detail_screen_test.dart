import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_log_entry.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/live_session_providers.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/work_session_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #32's acceptance criteria: destructive actions confirm, logs are
/// searchable and copyable, and `explain-error` is reachable from the screen.
void main() {
  final LiveSession runningWithError = LiveSession.fromJson(<String, Object?>{
    'id': 's-1',
    'projectId': 'codexbridge',
    'executorId': 'devel3',
    'instruction': 'Investigate the failing task',
    'state': 'running',
    'priority': 'normal',
    'revision': 7,
    'createdAt': '2026-08-15T12:00:00Z',
    'lastError': 'exit code 1',
  });

  Future<_ControlledSessionRepository> pumpDetail(
    WidgetTester tester, {
    List<LiveSessionLogEntry> logs = const <LiveSessionLogEntry>[],
  }) async {
    final _ControlledSessionRepository repository =
        _ControlledSessionRepository(session: runningWithError, logs: logs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gatewayContextProvider.overrideWith(
            (Ref ref) async => GatewayContext(
              server: Uri.parse('https://bridge.example.com'),
              accessToken: 'access-token',
            ),
          ),
          liveSessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const WorkSessionDetailScreen(sessionId: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('stop asks for confirmation before it is sent', (
    WidgetTester tester,
  ) async {
    final _ControlledSessionRepository repository = await pumpDetail(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pumpAndSettle();

    expect(find.text('Stop this session?'), findsOneWidget);
    expect(repository.lastAction, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Stop this session?'), findsNothing);
    expect(repository.lastAction, isNull);
  });

  testWidgets('confirming stop sends it', (WidgetTester tester) async {
    final _ControlledSessionRepository repository = await pumpDetail(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Stop'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastAction, LiveSessionControlAction.stop);
  });

  testWidgets('pause is not gated behind a confirmation', (
    WidgetTester tester,
  ) async {
    final _ControlledSessionRepository repository = await pumpDetail(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pause'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.lastAction, LiveSessionControlAction.pause);
  });

  testWidgets('explain error shows the reasons the gateway assembled', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester);

    await tester.tap(find.text('Explain error'));
    await tester.pumpAndSettle();

    expect(find.text('Why this session failed'), findsOneWidget);
    expect(find.text('• The executor reported an error.'), findsOneWidget);
  });

  testWidgets('logs are filtered by the search field', (
    WidgetTester tester,
  ) async {
    await pumpDetail(
      tester,
      logs: <LiveSessionLogEntry>[
        LiveSessionLogEntry(
          offset: 0,
          stream: 'stdout',
          line: 'starting up',
          at: DateTime.parse('2026-08-15T12:00:00Z'),
        ),
        LiveSessionLogEntry(
          offset: 1,
          stream: 'stderr',
          line: 'connection refused',
          at: DateTime.parse('2026-08-15T12:00:01Z'),
        ),
      ],
    );

    expect(find.textContaining('starting up'), findsOneWidget);
    expect(find.textContaining('connection refused'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'refused');
    await tester.pumpAndSettle();

    expect(find.textContaining('starting up'), findsNothing);
    expect(find.textContaining('connection refused'), findsOneWidget);
  });

  testWidgets('copying logs writes every visible line to the clipboard', (
    WidgetTester tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpDetail(
      tester,
      logs: <LiveSessionLogEntry>[
        LiveSessionLogEntry(
          offset: 0,
          stream: 'stdout',
          line: 'starting up',
          at: DateTime.parse('2026-08-15T12:00:00Z'),
        ),
      ],
    );

    await tester.tap(find.byTooltip('Copy all log lines'));
    await tester.pumpAndSettle();

    expect(copied, '[stdout] starting up');
  });
}

class _ControlledSessionRepository implements LiveSessionRepository {
  _ControlledSessionRepository({
    required this.session,
    this.logs = const <LiveSessionLogEntry>[],
  });

  final LiveSession session;
  final List<LiveSessionLogEntry> logs;
  LiveSessionControlAction? lastAction;

  @override
  Future<List<LiveSession>> loadSessions({
    required Uri server,
    required String accessToken,
  }) async => <LiveSession>[session];

  @override
  Future<LiveSession> loadSessionDetail({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async => session;

  @override
  Future<List<LiveSessionLogEntry>> loadSessionLogs({
    required Uri server,
    required String accessToken,
    required String sessionId,
    int offset = 0,
    int limit = 200,
  }) async => logs;

  @override
  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  }) async {
    lastAction = action;
    return session;
  }

  @override
  Future<LiveSessionErrorExplanation> explainError({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async {
    return LiveSessionErrorExplanation(
      sessionId: sessionId,
      state: 'failed',
      reasons: const <String>['The executor reported an error.'],
      recentStderr: const <LiveSessionLogEntry>[],
    );
  }
}
