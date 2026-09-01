import 'audit_event.dart';

/// Where audit events are written and read.
///
/// Deliberately two methods wide: append and read. There is no update, no
/// delete, and no way to hand a caller a mutable record — issue #46's
/// "records are immutable from normal UI" is enforced by this interface's
/// shape, not by every screen remembering not to offer an edit button.
///
/// The Codex Bridge gateway does not expose an audit API yet (CodexBridge #8
/// is open, unimplemented — checked 2026-08-26; its scope is epics/issues,
/// not audit, and no other backend issue covers this either), so the one
/// implementation today is [InMemoryAuditTrailRepository] — the same
/// deliberately-mocked stand-in `MockAuthGateway`/`MockDecisionRepository`
/// are for their own missing backends. When a server-side trail lands, an
/// HTTP implementation replaces the in-memory one behind this same
/// interface; call sites do not change.
abstract interface class AuditTrailRepository {
  /// Appends one event and returns it as stored — id and [AuditEvent.occurredAt]
  /// are assigned here, not by the caller, so no call site can back- or
  /// forward-date a record. [context] and [failureReason] are redacted at
  /// this boundary (`audit_redaction.dart`) before anything is kept.
  Future<AuditEvent> record({
    required String actor,
    required AuditArea area,
    required String action,
    required String target,
    required AuditResult result,
    String? failureReason,
    Map<String, String> context = const <String, String>{},
  });

  /// Every recorded event, newest first — the order a trail is read in.
  /// The returned list is unmodifiable.
  Future<List<AuditEvent>> loadEvents();
}
