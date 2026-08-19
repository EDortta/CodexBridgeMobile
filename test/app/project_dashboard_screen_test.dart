import 'package:codex_bridge_mobile/app/app.dart';
import 'package:codex_bridge_mobile/app/app_router.dart';
import 'package:codex_bridge_mobile/core/design/app_tokens.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decisions_screen.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_log_entry.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/live_session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #24's dashboard, pumped through the real router (same shape as
/// `app_router_test.dart`) so link-outs (`context.go`) resolve for real
/// instead of throwing for lack of a `GoRouter` ancestor.
///
/// The clock is pinned so staleness is deterministic — the mock repositories'
/// fixture dates were authored against this instant, not the real wall clock.
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 19, 12);

  Future<void> pumpDashboard(
    WidgetTester tester,
    String projectId, {
    List<LiveSession> sessions = const <LiveSession>[],
  }) async {
    // Seven grouped Card sections do not all fit the default test surface;
    // a tall viewport keeps every section's content built (a non-lazy
    // ListView still only builds what its Sliver lays out) without every
    // assertion needing its own scroll.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          gatewayContextProvider.overrideWith(
            (Ref ref) async => GatewayContext(
              server: Uri.parse('https://bridge.example.com'),
              accessToken: 'access-token',
            ),
          ),
          liveSessionRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(sessions),
          ),
        ],
        child: CodexBridgeMobileApp(
          router: createAppRouter(
            initialLocation: '/projects/detail?project=$projectId',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every populated section for a real project', (
    WidgetTester tester,
  ) async {
    // A session for a DIFFERENT project, so the device-wide session list is
    // non-empty (RemoteSessionsState.information stays null) and the
    // dashboard's own per-project empty message is what actually renders,
    // rather than RemoteSessionsController's global
    // "No sessions are visible from this device." fallback.
    final LiveSession otherProjectSession = LiveSession.fromJson(<String, Object?>{
      'id': 's-elsewhere',
      'projectId': 'codex-bridge-mobile',
      'executorId': 'devel3',
      'instruction': 'Unrelated work',
      'state': 'running',
      'priority': 'normal',
      'revision': 1,
      'createdAt': '2026-08-19T09:00:00Z',
    });
    await pumpDashboard(
      tester,
      'codex-bridge-desktop',
      sessions: <LiveSession>[otherProjectSession],
    );

    expect(find.text('Pending decision'), findsWidgets);
    expect(find.text('Desktop shell review'), findsOneWidget);
    expect(find.text('Keyboard shortcut conflicts with the OS'), findsOneWidget);
    expect(find.text('Approve the desktop color palette'), findsOneWidget);
    expect(find.text('Cut the next desktop release'), findsOneWidget);
    expect(find.text('release-notes-draft.md'), findsOneWidget);
    expect(find.text('Design review requested'), findsOneWidget);
    expect(find.text('No sessions for this project.'), findsOneWidget);
  });

  testWidgets('shows empty states for a project with no mission, issues or decisions', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, 'codex-bridge-cli');

    expect(find.text('No active mission.'), findsOneWidget);
    expect(find.text('No open issues for this project.'), findsOneWidget);
    expect(find.text('No pending decisions for this project.'), findsOneWidget);
  });

  testWidgets(
    'marks stale decisions, artifacts and activity with the clock icon',
    (WidgetTester tester) async {
      // codex-bridge-desktop: one fresh decision (requested 2h before the
      // pinned "now") and one stale decision (3+ days before it, past the
      // 24h threshold); its artifact and activity entry are both fresh
      // (under the 7-day threshold). Exactly one stale marker expected —
      // the RelativeMoment threshold math itself is pinned precisely by
      // `relative_moment_test.dart`; this only checks it is wired into the
      // rendered page for real fixture data.
      await pumpDashboard(tester, 'codex-bridge-desktop');
      expect(find.byIcon(AppIcons.stale), findsOneWidget);

      // codex-bridge-cli: no decisions; its one artifact (18 days old) and
      // its one activity entry (14 days old) are both past the 7-day
      // threshold — two stale markers expected.
      await pumpDashboard(tester, 'codex-bridge-cli');
      expect(find.byIcon(AppIcons.stale), findsNWidgets(2));
    },
  );

  testWidgets('an unknown project id renders the not-found state', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, 'does-not-exist');

    expect(find.text('Project "does-not-exist" was not found.'), findsOneWidget);
  });

  testWidgets('tapping a priority issue opens a dialog with its detail', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, 'codex-bridge-desktop');

    await tester.tap(find.text('Keyboard shortcut conflicts with the OS'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Priority: Normal\nProject: codex-bridge-desktop'), findsOneWidget);
  });

  testWidgets('tapping a pending decision navigates to Decisions', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, 'codex-bridge-desktop');

    await tester.tap(find.text('Approve the desktop color palette'));
    await tester.pumpAndSettle();

    expect(find.byType(DecisionsScreen), findsOneWidget);
  });

  testWidgets('tapping a recent artifact opens a dialog with its detail', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, 'codex-bridge-desktop');

    await tester.tap(find.text('release-notes-draft.md'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Project: codex-bridge-desktop'), findsOneWidget);
  });

  testWidgets('a live session for the project renders as a full SessionCard', (
    WidgetTester tester,
  ) async {
    final LiveSession session = LiveSession.fromJson(<String, Object?>{
      'id': 's-1',
      'projectId': 'codex-bridge-desktop',
      'executorId': 'devel3',
      'instruction': 'Ship the release',
      'state': 'running',
      'priority': 'normal',
      'revision': 1,
      'createdAt': '2026-08-19T09:00:00Z',
    });

    await pumpDashboard(tester, 'codex-bridge-desktop', sessions: <LiveSession>[session]);

    expect(find.text('Ship the release'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
  });
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
