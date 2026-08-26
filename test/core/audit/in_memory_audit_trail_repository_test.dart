import 'package:codex_bridge_mobile/core/audit/audit_event.dart';
import 'package:codex_bridge_mobile/core/audit/audit_redaction.dart';
import 'package:codex_bridge_mobile/core/audit/in_memory_audit_trail_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// #46: the store is append-only and immutable from the outside — no update,
/// no delete, no mutable reference handed to any caller.
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 26, 15);

  InMemoryAuditTrailRepository repository() =>
      InMemoryAuditTrailRepository(clock: () => pinnedNow);

  test('records actor, action, target, time, result and context', () async {
    final InMemoryAuditTrailRepository store = repository();

    final AuditEvent event = await store.record(
      actor: 'op-1',
      area: AuditArea.decision,
      action: 'approve',
      target: 'shell-review',
      result: AuditResult.success,
      context: <String, String>{'commentProvided': 'false'},
    );

    expect(event.id, 'audit-1');
    expect(event.actor, 'op-1');
    expect(event.area, AuditArea.decision);
    expect(event.action, 'approve');
    expect(event.target, 'shell-review');
    expect(event.occurredAt, pinnedNow);
    expect(event.result, AuditResult.success);
    expect(event.context, <String, String>{'commentProvided': 'false'});
    expect(event.failureReason, isNull);
  });

  test('loadEvents returns newest first', () async {
    final InMemoryAuditTrailRepository store = repository();
    await store.record(
      actor: 'op-1',
      area: AuditArea.mission,
      action: 'pause',
      target: 'm-1',
      result: AuditResult.success,
    );
    await store.record(
      actor: 'op-1',
      area: AuditArea.mission,
      action: 'cancel',
      target: 'm-1',
      result: AuditResult.cancelled,
    );

    final List<AuditEvent> events = await store.loadEvents();
    expect(events.map((AuditEvent e) => e.action), <String>['cancel', 'pause']);
  });

  test('ids are unique and monotonic across events', () async {
    final InMemoryAuditTrailRepository store = repository();
    for (int i = 0; i < 3; i++) {
      await store.record(
        actor: 'op-1',
        area: AuditArea.liveSession,
        action: 'stop',
        target: 's-$i',
        result: AuditResult.success,
      );
    }
    final List<AuditEvent> events = await store.loadEvents();
    expect(events.map((AuditEvent e) => e.id).toSet().length, 3);
  });

  test('the returned list rejects mutation', () async {
    final InMemoryAuditTrailRepository store = repository();
    await store.record(
      actor: 'op-1',
      area: AuditArea.decision,
      action: 'reject',
      target: 'd-1',
      result: AuditResult.success,
    );

    final List<AuditEvent> events = await store.loadEvents();
    expect(() => events.removeAt(0), throwsUnsupportedError);
    expect(() => events.clear(), throwsUnsupportedError);
  });

  test('an event context rejects mutation through a retained reference', () async {
    final InMemoryAuditTrailRepository store = repository();
    final Map<String, String> handedIn = <String, String>{'k': 'v'};
    final AuditEvent event = await store.record(
      actor: 'op-1',
      area: AuditArea.decision,
      action: 'approve',
      target: 'd-1',
      result: AuditResult.success,
      context: handedIn,
    );

    expect(() => event.context['k'] = 'edited', throwsUnsupportedError);
    // Editing the map the caller kept must not reach the stored record.
    handedIn['k'] = 'edited';
    final List<AuditEvent> events = await store.loadEvents();
    expect(events.single.context['k'], 'v');
  });

  test('redacts sensitive context and credential-shaped reasons at the boundary', () async {
    final InMemoryAuditTrailRepository store = repository();
    const String jwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJvcGVyYXRvciJ9.c2lnbmF0dXJlLXNlZ21lbnQ';
    final AuditEvent event = await store.record(
      actor: 'op-1',
      area: AuditArea.liveSession,
      action: 'stop',
      target: 's-1',
      result: AuditResult.failure,
      failureReason: 'gateway refused token $jwt',
      context: <String, String>{'accessToken': 'raw-secret'},
    );

    expect(event.context['accessToken'], redactedPlaceholder);
    expect(event.failureReason, isNot(contains(jwt)));
  });

  test('stores time as UTC even from a local clock', () async {
    final InMemoryAuditTrailRepository store = InMemoryAuditTrailRepository(
      clock: () => DateTime(2026, 8, 26, 12),
    );
    final AuditEvent event = await store.record(
      actor: 'op-1',
      area: AuditArea.decision,
      action: 'approve',
      target: 'd-1',
      result: AuditResult.success,
    );
    expect(event.occurredAt.isUtc, isTrue);
  });
}
