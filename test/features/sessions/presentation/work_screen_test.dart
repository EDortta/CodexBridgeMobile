import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_log_entry.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/live_session_providers.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #31's "intervention requests prominent" acceptance criterion, closed
/// as part of the #32 delivery but shipped with no test — `grep -rn
/// "Needs your approval|awaitingApproval" test/` matched nothing (council
/// 2026-08-18, "the claim auditor").
void main() {
  testWidgets(
    'a session awaiting approval carries the intervention label; others do not',
    (WidgetTester tester) async {
      final LiveSession awaiting = LiveSession.fromJson(<String, Object?>{
        'id': 's-1',
        'projectId': 'codexbridge',
        'executorId': 'devel3',
        'instruction': 'Needs a decision before it can continue',
        'state': 'awaiting_approval',
        'priority': 'normal',
        'revision': 1,
        'createdAt': '2026-08-15T12:00:00Z',
      });
      final LiveSession running = LiveSession.fromJson(<String, Object?>{
        'id': 's-2',
        'projectId': 'codexbridge',
        'executorId': 'devel3',
        'instruction': 'Already underway',
        'state': 'running',
        'priority': 'normal',
        'revision': 1,
        'createdAt': '2026-08-15T12:00:00Z',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            gatewayContextProvider.overrideWith(
              (Ref ref) async => GatewayContext(
                server: Uri.parse('https://bridge.example.com'),
                accessToken: 'access-token',
              ),
            ),
            liveSessionRepositoryProvider.overrideWithValue(
              _FakeSessionsRepository(<LiveSession>[awaiting, running]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const WorkScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs your approval'), findsOneWidget);
    },
  );
}

class _FakeSessionsRepository implements LiveSessionRepository {
  const _FakeSessionsRepository(this.sessions);

  final List<LiveSession> sessions;

  @override
  Future<List<LiveSession>> loadSessions({
    required Uri server,
    required String accessToken,
  }) async => sessions;

  @override
  Future<LiveSession> loadSessionDetail({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async => sessions.firstWhere((LiveSession item) => item.id == sessionId);

  @override
  Future<List<LiveSessionLogEntry>> loadSessionLogs({
    required Uri server,
    required String accessToken,
    required String sessionId,
    int offset = 0,
    int limit = 200,
  }) async => const <LiveSessionLogEntry>[];

  @override
  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  }) async => sessions.firstWhere((LiveSession item) => item.id == sessionId);

  @override
  Future<LiveSessionErrorExplanation> explainError({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async {
    return LiveSessionErrorExplanation(
      sessionId: sessionId,
      state: 'failed',
      reasons: const <String>[],
      recentStderr: const <LiveSessionLogEntry>[],
    );
  }
}
