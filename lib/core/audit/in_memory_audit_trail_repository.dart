import 'audit_event.dart';
import 'audit_redaction.dart';
import 'audit_trail_repository.dart';

/// The in-memory [AuditTrailRepository] — the stand-in for a backend that
/// does not exist yet (no CodexBridge audit API; see the interface's doc
/// comment), the same role `MockAuthGateway` and `MockDecisionRepository`
/// play for theirs.
///
/// Append-only by construction: the private list is only ever added to, and
/// [loadEvents] returns an unmodifiable copy, so no caller — screen, test,
/// or future code — can edit or remove a record through this class
/// (#46: "records are immutable from normal UI"). In-memory means the trail
/// lasts as long as the process; durable storage is the server-side trail's
/// job when its API lands, not a device-local file this threat model would
/// then have to protect (`security-threat-model.md` §Assets lists audit
/// records as Medium–High sensitivity).
class InMemoryAuditTrailRepository implements AuditTrailRepository {
  InMemoryAuditTrailRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.timestamp;

  final DateTime Function() _clock;
  final List<AuditEvent> _events = <AuditEvent>[];
  int _nextId = 1;

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
    final AuditEvent event = AuditEvent(
      id: 'audit-${_nextId++}',
      // Actor and target pass through value redaction too: neither should
      // ever contain a credential, and if a future call site gets that
      // wrong, the mistake stops here instead of being stored.
      actor: redactAuditValue(actor),
      area: area,
      action: action,
      target: redactAuditValue(target),
      occurredAt: _clock().toUtc(),
      result: result,
      failureReason: failureReason == null
          ? null
          : redactAuditValue(failureReason),
      context: redactAuditContext(context),
    );
    _events.add(event);
    return event;
  }

  @override
  Future<List<AuditEvent>> loadEvents() async {
    return List<AuditEvent>.unmodifiable(_events.reversed);
  }
}
