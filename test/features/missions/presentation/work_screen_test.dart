import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_log_entry.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/live_session_providers.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_providers.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #27's mission list/filter UI. `test/features/sessions/presentation/work_screen_test.dart`
/// (misnamed directory, pre-existing) covers the live-sessions half of this
/// same screen; this file covers the mission half.
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 19, 12);

  Mission missionWith({
    required String id,
    required String projectId,
    required String title,
    MissionStage stage = MissionStage.implementation,
    MissionRisk risk = MissionRisk.low,
    MissionState state = MissionState.active,
    String? blockedReason,
  }) {
    return Mission(
      id: id,
      projectId: projectId,
      title: title,
      status: 'Status',
      stage: stage,
      risk: risk,
      state: state,
      owner: 'Claude',
      progress: 0.5,
      startedAt: pinnedNow.subtract(const Duration(hours: 3)),
      latestEvent: 'Something happened recently',
      blockedReason: blockedReason,
    );
  }

  final Mission blocked = missionWith(
    id: 'blocked-mission',
    projectId: 'codex-bridge',
    title: 'Fix the build',
    stage: MissionStage.testing,
    risk: MissionRisk.high,
    state: MissionState.blocked,
    blockedReason: 'Waiting on infra.',
  );
  final Mission routine = missionWith(
    id: 'routine-mission',
    projectId: 'codex-bridge-mobile',
    title: 'Ship the release',
    stage: MissionStage.planning,
    risk: MissionRisk.low,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Mission> missions = const <Mission>[],
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          missionRepositoryProvider.overrideWithValue(
            _FakeMissionRepository(missions),
          ),
          gatewayContextProvider.overrideWith(
            (Ref ref) async => GatewayContext(
              server: Uri.parse('https://bridge.example.com'),
              accessToken: 'access-token',
            ),
          ),
          liveSessionRepositoryProvider.overrideWithValue(
            const _FakeSessionsRepository(<LiveSession>[]),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WorkScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders owner, stage, risk, state, progress and latest event', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[routine]);

    expect(find.text('Ship the release'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Planning'), findsWidgets);
    expect(find.text('Low risk'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Something happened recently'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.textContaining('Started'), findsOneWidget);
  });

  testWidgets('a blocked mission shows the intervention banner and its reason', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[blocked]);

    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.text('Waiting on infra.'), findsOneWidget);
  });

  testWidgets('an active mission does not show the intervention banner', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[routine]);

    expect(find.text('Needs your attention'), findsNothing);
  });

  testWidgets('the stage filter narrows to that stage', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[blocked, routine]);

    await tester.tap(find.byKey(const Key('missionStageFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testing').last);
    await tester.pumpAndSettle();

    expect(find.text('Fix the build'), findsOneWidget);
    expect(find.text('Ship the release'), findsNothing);
  });

  testWidgets('the state filter narrows to blocked missions only', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[blocked, routine]);

    await tester.tap(find.byKey(const Key('missionStateFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocked').last);
    await tester.pumpAndSettle();

    expect(find.text('Fix the build'), findsOneWidget);
    expect(find.text('Ship the release'), findsNothing);
  });

  testWidgets('a no-match filter combination shows the empty state, clearable', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, missions: <Mission>[blocked, routine]);

    await tester.tap(find.byKey(const Key('missionStateFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();

    expect(find.text('No missions match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Fix the build'), findsOneWidget);
    expect(find.text('Ship the release'), findsOneWidget);
  });

  testWidgets('no missions at all shows the plain empty state', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('No missions yet.'), findsOneWidget);
  });
}

class _FakeMissionRepository implements MissionRepository {
  const _FakeMissionRepository(this.missions);

  final List<Mission> missions;

  @override
  Future<List<Mission>> loadMissions() => Future<List<Mission>>.value(missions);
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
