import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_log_entry.dart';
import 'package:codex_bridge_mobile/features/missions/domain/live_session_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/live_session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSessionRepository implements LiveSessionRepository {
  FakeSessionRepository({
    required this.sessions,
    this.detailResult,
    this.logs = const <LiveSessionLogEntry>[],
    this.controlResult,
    this.detailDelay = Duration.zero,
    this.controlDelay = Duration.zero,
  });

  final List<LiveSession> sessions;
  final LiveSession? detailResult;
  final List<LiveSessionLogEntry> logs;
  final LiveSession? controlResult;
  final Duration detailDelay;
  final Duration controlDelay;
  LiveSessionControlAction? lastAction;
  int detailCallCount = 0;
  int controlCallCount = 0;

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
  }) async {
    detailCallCount++;
    if (detailDelay > Duration.zero) {
      await Future<void>.delayed(detailDelay);
    }
    return detailResult ?? sessions.first;
  }

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
    controlCallCount++;
    lastAction = action;
    if (controlDelay > Duration.zero) {
      await Future<void>.delayed(controlDelay);
    }
    return controlResult ?? sessions.first;
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

void main() {
  test('reports the missing prerequisites explicitly', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final RemoteSessionsState state = await container.read(
      remoteSessionsProvider.future,
    );

    expect(state.sessions, isEmpty);
    expect(
      state.information,
      'Select a server and sign in to control live sessions.',
    );
  });

  test('loads sessions from the selected server and sends controls back', () async {
    final GatewayContext gatewayContext = GatewayContext(
      server: Uri.parse('https://bridge.example.com'),
      accessToken: 'access-token',
    );

    final LiveSession running = LiveSession.fromJson(<String, Object?>{
      'id': 's-1',
      'projectId': 'codexbridge',
      'executorId': 'devel3',
      'instruction': 'Investigate the failing task',
      'state': 'running',
      'priority': 'normal',
      'revision': 7,
      'createdAt': '2026-08-15T12:00:00Z',
    });
    final LiveSession pausing = LiveSession.fromJson(<String, Object?>{
      'id': 's-1',
      'projectId': 'codexbridge',
      'executorId': 'devel3',
      'instruction': 'Investigate the failing task',
      'state': 'pausing',
      'priority': 'normal',
      'revision': 8,
      'createdAt': '2026-08-15T12:00:00Z',
    });
    final FakeSessionRepository repository = FakeSessionRepository(
      sessions: <LiveSession>[running],
      controlResult: pausing,
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gatewayContextProvider.overrideWith((Ref ref) async => gatewayContext),
        liveSessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final RemoteSessionsState loaded = await container.read(
      remoteSessionsProvider.future,
    );
    expect(loaded.sessions.single.state, LiveSessionState.running);

    await container
        .read(remoteSessionsProvider.notifier)
        .control('s-1', LiveSessionControlAction.pause);

    final RemoteSessionsState updated = container.read(
      remoteSessionsProvider,
    ).requireValue;
    expect(repository.lastAction, LiveSessionControlAction.pause);
    expect(updated.sessions.single.state, LiveSessionState.pausing);
  });

  test('loads detail and logs for a selected session', () async {
    final GatewayContext gatewayContext = GatewayContext(
      server: Uri.parse('https://bridge.example.com'),
      accessToken: 'access-token',
    );

    final LiveSession detail = LiveSession.fromJson(<String, Object?>{
      'id': 's-2',
      'projectId': 'codexbridge',
      'executorId': 'devel3',
      'instruction': 'Summarize the failed rollout',
      'state': 'failed',
      'priority': 'normal',
      'revision': 11,
      'createdAt': '2026-08-15T12:00:00Z',
      'completedAt': '2026-08-15T12:04:00Z',
      'requestedBy': 'alice@example.com',
      'lastError': 'exit code 1',
    });
    final FakeSessionRepository repository = FakeSessionRepository(
      sessions: <LiveSession>[detail],
      detailResult: detail,
      logs: <LiveSessionLogEntry>[
        LiveSessionLogEntry(
          offset: 0,
          stream: 'stderr',
          line: 'first failing line',
          at: DateTime.parse('2026-08-15T12:03:30Z'),
        ),
      ],
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gatewayContextProvider.overrideWith((Ref ref) async => gatewayContext),
        liveSessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final LiveSession loadedDetail = await container.read(
      liveSessionDetailProvider('s-2').future,
    );
    final List<LiveSessionLogEntry> loadedLogs = await container.read(
      liveSessionLogsProvider('s-2').future,
    );

    expect(loadedDetail.state, LiveSessionState.failed);
    expect(loadedDetail.lastError, 'exit code 1');
    expect(loadedLogs.single.line, 'first failing line');
  });

  test(
    'controls a session outside the cached list by fetching its revision directly',
    () async {
      final GatewayContext gatewayContext = GatewayContext(
        server: Uri.parse('https://bridge.example.com'),
        accessToken: 'access-token',
      );

      final LiveSession outsideScope = LiveSession.fromJson(<String, Object?>{
        'id': 's-3',
        'projectId': 'codexbridge',
        'executorId': 'devel3',
        'instruction': 'Reachable only by id, not by the list',
        'state': 'running',
        'priority': 'normal',
        'revision': 42,
        'createdAt': '2026-08-15T12:00:00Z',
      });
      // loadSessions() deliberately does NOT include 's-3' — a cold
      // navigation into a session outside remoteSessionsProvider's own scope
      // (council 2026-08-18, "the sweep skeptic" / "the second caller").
      final FakeSessionRepository repository = FakeSessionRepository(
        sessions: const <LiveSession>[],
        detailResult: outsideScope,
        controlResult: outsideScope,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          gatewayContextProvider.overrideWith((Ref ref) async => gatewayContext),
          liveSessionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final RemoteSessionsState loaded = await container.read(
        remoteSessionsProvider.future,
      );
      expect(loaded.sessions, isEmpty);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-3', LiveSessionControlAction.pause);

      expect(repository.detailCallCount, 1);
      expect(repository.controlCallCount, 1);
      expect(repository.lastAction, LiveSessionControlAction.pause);
      final RemoteSessionsState after = container.read(
        remoteSessionsProvider,
      ).requireValue;
      expect(after.error, isNull);
    },
  );

  test(
    'a second tap on the same session while one is in flight is a no-op',
    () async {
      final GatewayContext gatewayContext = GatewayContext(
        server: Uri.parse('https://bridge.example.com'),
        accessToken: 'access-token',
      );

      final LiveSession outsideScope = LiveSession.fromJson(<String, Object?>{
        'id': 's-4',
        'projectId': 'codexbridge',
        'executorId': 'devel3',
        'instruction': 'Slow to fetch, so two taps can race',
        'state': 'running',
        'priority': 'normal',
        'revision': 1,
        'createdAt': '2026-08-15T12:00:00Z',
      });
      final FakeSessionRepository repository = FakeSessionRepository(
        sessions: const <LiveSession>[],
        detailResult: outsideScope,
        controlResult: outsideScope,
        // The gap this council finding lives in: the network round trip
        // _revisionFor's fallback needs before `pending` used to be set.
        detailDelay: const Duration(milliseconds: 50),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          gatewayContextProvider.overrideWith((Ref ref) async => gatewayContext),
          liveSessionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(remoteSessionsProvider.future);

      final RemoteSessionsController controller = container.read(
        remoteSessionsProvider.notifier,
      );
      final Future<void> first = controller.control(
        's-4',
        LiveSessionControlAction.pause,
      );
      // Fired while the first call is still awaiting loadSessionDetail —
      // before this fix, `pending` was not set yet at this point.
      final Future<void> second = controller.control(
        's-4',
        LiveSessionControlAction.pause,
      );
      await Future.wait(<Future<void>>[first, second]);

      expect(
        repository.controlCallCount,
        1,
        reason: 'the second tap must not submit a duplicate control action',
      );
    },
  );
}
