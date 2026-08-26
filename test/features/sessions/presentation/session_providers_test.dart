import 'package:codex_bridge_mobile/core/audit/audit_event.dart';
import 'package:codex_bridge_mobile/core/audit/audit_providers.dart';
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

  // #46: every control outcome lands on the cross-cutting audit trail.
  group('audit trail', () {
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

    ProviderContainer auditedContainer({
      required LiveSessionRepository repository,
      GatewayContext? gatewayContext,
    }) {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          auditActorProvider.overrideWithValue('op-42'),
          gatewayContextProvider.overrideWith(
            (Ref ref) async => gatewayContext,
          ),
          liveSessionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a successful control records success with the actor', () async {
      final ProviderContainer container = auditedContainer(
        repository: FakeSessionRepository(
          sessions: <LiveSession>[running],
          controlResult: running,
        ),
        gatewayContext: GatewayContext(
          server: Uri.parse('https://bridge.example.com'),
          accessToken: 'access-token',
        ),
      );
      await container.read(remoteSessionsProvider.future);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-1', LiveSessionControlAction.stop);

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.area, AuditArea.liveSession);
      expect(event.action, 'stop');
      expect(event.target, 's-1');
      expect(event.actor, 'op-42');
      expect(event.result, AuditResult.success);
    });

    test('a control refused by the gateway records failure with the reason', () async {
      final ProviderContainer container = auditedContainer(
        repository: _ControlRefusedRepository(
          sessions: <LiveSession>[running],
        ),
        gatewayContext: GatewayContext(
          server: Uri.parse('https://bridge.example.com'),
          accessToken: 'access-token',
        ),
      );
      await container.read(remoteSessionsProvider.future);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-1', LiveSessionControlAction.stop);

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.result, AuditResult.failure);
      expect(event.failureReason, 'The gateway refused the stop.');
    });

    test('a control stopped by a missing gateway context records failure', () async {
      final ProviderContainer container = auditedContainer(
        repository: FakeSessionRepository(sessions: <LiveSession>[running]),
      );
      await container.read(remoteSessionsProvider.future);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-1', LiveSessionControlAction.pause);

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.action, 'pause');
      expect(event.result, AuditResult.failure);
      expect(
        event.failureReason,
        'No server selected or no signed-in session.',
      );
      // Nobody needs to be signed in for the refusal itself to be a fact.
      expect(event.actor, 'op-42');
    });

    test('a malformed success payload still clears pending and records failure', () async {
      // council 2026-08-26, the adversarial user, round 1: a 200 whose body
      // fails `LiveSession.fromJson` used to escape the repository-typed
      // catch — `pending` stayed stuck and no failure was recorded.
      final ProviderContainer container = auditedContainer(
        repository: _MalformedPayloadRepository(
          sessions: <LiveSession>[running],
        ),
        gatewayContext: GatewayContext(
          server: Uri.parse('https://bridge.example.com'),
          accessToken: 'access-token',
        ),
      );
      await container.read(remoteSessionsProvider.future);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-1', LiveSessionControlAction.stop);

      final RemoteSessionsState after =
          container.read(remoteSessionsProvider).requireValue;
      expect(after.pending, isEmpty,
          reason: 'a failed control must re-enable its buttons');
      expect(after.error, contains('invalid_session_payload'));

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.result, AuditResult.failure);
      expect(event.failureReason, contains('invalid_session_payload'));
    });

    test('a malformed revision-fetch payload also clears pending and records failure', () async {
      // council 2026-08-26, the adversarial user, round 2: the first fix's
      // test only exercised the `controlSession` catch — a regression
      // narrowing the *revision-fetch* catch back to the repository's own
      // exception type would have passed the whole suite. This pins the
      // cold-navigation half: the session is absent from the cached list,
      // so `_revisionFor` falls back to `loadSessionDetail`, which throws.
      final ProviderContainer container = auditedContainer(
        repository: _MalformedDetailRepository(),
        gatewayContext: GatewayContext(
          server: Uri.parse('https://bridge.example.com'),
          accessToken: 'access-token',
        ),
      );
      await container.read(remoteSessionsProvider.future);

      await container
          .read(remoteSessionsProvider.notifier)
          .control('s-cold', LiveSessionControlAction.pause);

      final RemoteSessionsState after =
          container.read(remoteSessionsProvider).requireValue;
      expect(after.pending, isEmpty);
      expect(after.error, contains('invalid_session_payload'));

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.action, 'pause');
      expect(event.result, AuditResult.failure);
      expect(event.failureReason, contains('invalid_session_payload'));
    });

    test('a suppressed duplicate tap records nothing extra', () async {
      final FakeSessionRepository repository = FakeSessionRepository(
        sessions: const <LiveSession>[],
        detailResult: running,
        controlResult: running,
        detailDelay: const Duration(milliseconds: 50),
      );
      final ProviderContainer container = auditedContainer(
        repository: repository,
        gatewayContext: GatewayContext(
          server: Uri.parse('https://bridge.example.com'),
          accessToken: 'access-token',
        ),
      );
      await container.read(remoteSessionsProvider.future);

      final RemoteSessionsController controller = container.read(
        remoteSessionsProvider.notifier,
      );
      await Future.wait(<Future<void>>[
        controller.control('s-1', LiveSessionControlAction.pause),
        controller.control('s-1', LiveSessionControlAction.pause),
      ]);

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      expect(events, hasLength(1));
    });
  });
}

/// Answers the *revision-fetch* detail read with the exception a malformed
/// 200 payload raises — the cached list stays empty so `_revisionFor` must
/// take its fallback branch.
class _MalformedDetailRepository extends FakeSessionRepository {
  _MalformedDetailRepository() : super(sessions: const <LiveSession>[]);

  @override
  Future<LiveSession> loadSessionDetail({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async {
    throw const FormatException('invalid_session_payload');
  }
}

/// Answers a control with the exception a malformed 200 payload raises.
class _MalformedPayloadRepository extends FakeSessionRepository {
  _MalformedPayloadRepository({required super.sessions});

  @override
  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  }) async {
    throw const FormatException('invalid_session_payload');
  }
}

/// Refuses every control the way a gateway would; loads pass through.
class _ControlRefusedRepository extends FakeSessionRepository {
  _ControlRefusedRepository({required super.sessions});

  @override
  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  }) async {
    throw LiveSessionRepositoryException(
      'The gateway refused the ${action.name}.',
    );
  }
}
