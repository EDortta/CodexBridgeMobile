import 'package:codex_bridge_mobile/core/audit/audit_event.dart';
import 'package:codex_bridge_mobile/core/audit/audit_providers.dart';
import 'package:codex_bridge_mobile/core/audit/audit_trail_repository.dart';
import 'package:codex_bridge_mobile/core/audit/in_memory_audit_trail_repository.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingAuditTrailRepository implements AuditTrailRepository {
  @override
  Future<AuditEvent> record({
    required String actor,
    required AuditArea area,
    required String action,
    required String target,
    required AuditResult result,
    String? failureReason,
    Map<String, String> context = const <String, String>{},
  }) async {
    throw Exception('store refused the write');
  }

  @override
  Future<List<AuditEvent>> loadEvents() async => const <AuditEvent>[];
}

void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 26, 15);

  test('records with the resolved actor', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
        auditActorProvider.overrideWithValue('op-42'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(auditRecorderProvider).record(
      area: AuditArea.decision,
      action: 'approve',
      target: 'd-1',
      result: AuditResult.success,
    );

    final List<AuditEvent> events =
        await container.read(auditTrailRepositoryProvider).loadEvents();
    expect(events.single.actor, 'op-42');
  });

  test('falls back to "unknown" when nobody is signed in', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
      ],
    );
    addTearDown(container.dispose);

    await container.read(auditRecorderProvider).record(
      area: AuditArea.liveSession,
      action: 'stop',
      target: 's-1',
      result: AuditResult.failure,
      failureReason: 'No server selected or no signed-in session.',
    );

    final List<AuditEvent> events =
        await container.read(auditTrailRepositoryProvider).loadEvents();
    expect(events.single.actor, unknownAuditActor);
  });

  test('reads the actor at record time, not at construction time', () async {
    String? actor;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
        auditActorProvider.overrideWith((Ref ref) => actor),
      ],
    );
    addTearDown(container.dispose);

    final AuditRecorder recorder = container.read(auditRecorderProvider);
    actor = 'op-7';

    await recorder.record(
      area: AuditArea.mission,
      action: 'cancel',
      target: 'm-1',
      result: AuditResult.success,
    );

    final List<AuditEvent> events =
        await container.read(auditTrailRepositoryProvider).loadEvents();
    expect(events.single.actor, 'op-7');
  });

  test('a store that throws does not break the operation being audited', () async {
    final AuditRecorder recorder = AuditRecorder(
      _ThrowingAuditTrailRepository(),
      () => 'op-1',
    );

    await expectLater(
      recorder.record(
        area: AuditArea.decision,
        action: 'approve',
        target: 'd-1',
        result: AuditResult.success,
      ),
      completes,
    );
  });

  test('recording invalidates auditEventsProvider for a mounted listener', () async {
    // The shell keeps every branch mounted, so a trail screen's listener
    // survives destination switches and autoDispose never fires — the
    // recorder itself must push the refresh (council 2026-08-26, the
    // second caller, round 1).
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<AsyncValue<List<AuditEvent>>> subscription =
        container.listen(auditEventsProvider, (AsyncValue<List<AuditEvent>>? previous, AsyncValue<List<AuditEvent>> next) {});
    addTearDown(subscription.close);
    expect(await container.read(auditEventsProvider.future), isEmpty);

    await container.read(auditRecorderProvider).record(
      area: AuditArea.decision,
      action: 'approve',
      target: 'd-1',
      result: AuditResult.success,
    );

    final List<AuditEvent> refreshed =
        await container.read(auditEventsProvider.future);
    expect(refreshed, hasLength(1));
  });

  test('the repository provider hands every reader the same trail', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
      ],
    );
    addTearDown(container.dispose);

    final AuditTrailRepository first =
        container.read(auditTrailRepositoryProvider);
    final AuditTrailRepository second =
        container.read(auditTrailRepositoryProvider);
    expect(identical(first, second), isTrue);
    expect(first, isA<InMemoryAuditTrailRepository>());
  });
}
