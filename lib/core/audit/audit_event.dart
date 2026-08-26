/// One recorded sensitive operation — issue #46's "actor, action, target,
/// time, result and relevant context".
///
/// Lives in `core/` rather than in a feature because the operations it
/// records happen in several features at once (decisions, missions/live
/// sessions today; file access and installation flows when #37–#39 land) and
/// a feature must never import another feature
/// (`docs/architecture/state-architecture.md`) — the same argument that put
/// `SecureKeyValueStore` and `GatewayContext` here.
library;

/// Which kind of surface an audited operation belongs to.
///
/// [fileAccess] and [installation] have no call site yet — #39 (SAF) and
/// #37/#38 (APK install) are unbuilt. They are declared now because the
/// threat model already binds them to this trail (R8: "Every install attempt
/// — offered, accepted, refused, failed — is an audit event (#46)"; R9), so
/// the category exists the day those flows are written instead of being
/// invented ad hoc inside them.
enum AuditArea {
  /// Resolving a decision: approve, reject, request revision (#26).
  decision,

  /// Controlling a live remote session: pause, resume, restart, stop (#31/#32).
  liveSession,

  /// Controlling a mission: pause, resume, cancel (#28).
  mission,

  /// Reading a user-selected file through SAF — #39, not built yet.
  fileAccess,

  /// Offering/installing an APK — #37/#38, not built yet.
  installation;

  String get label => switch (this) {
    AuditArea.decision => 'Decision',
    AuditArea.liveSession => 'Live session',
    AuditArea.mission => 'Mission',
    AuditArea.fileAccess => 'File access',
    AuditArea.installation => 'Installation',
  };
}

/// How an audited operation ended.
///
/// Three outcomes, not one: issue #46's acceptance criterion says "failed
/// and cancelled operations are included" — an audit trail that only ever
/// says "success" is a changelog, not a trail.
enum AuditResult {
  /// The operation completed as asked.
  success,

  /// The operation was attempted and did not complete — the gateway refused
  /// it, the repository threw, or a precondition (no server, no session)
  /// stopped it before it could be sent.
  failure,

  /// The operator started the operation and backed out at its confirmation
  /// step. Nothing was sent; the intent is still recorded.
  cancelled;

  String get label => switch (this) {
    AuditResult.success => 'Success',
    AuditResult.failure => 'Failed',
    AuditResult.cancelled => 'Cancelled',
  };
}

class AuditEvent {
  /// [context] is defensively copied into an unmodifiable map — an event,
  /// once constructed, cannot be edited through a retained reference
  /// (#46: "records are immutable from normal UI").
  AuditEvent({
    required this.id,
    required this.actor,
    required this.area,
    required this.action,
    required this.target,
    required this.occurredAt,
    required this.result,
    this.failureReason,
    Map<String, String> context = const <String, String>{},
  }) : context = Map<String, String>.unmodifiable(context);

  final String id;

  /// Who did it — the signed-in operator's id, or `unknown` when no session
  /// identifies one (see `auditActorProvider`). Server-resolved identity,
  /// never free text typed on this device.
  final String actor;

  final AuditArea area;

  /// The verb, in the vocabulary of [area]: `approve`, `reject`,
  /// `requestRevision`, `pause`, `resume`, `restart`, `stop`, `cancel`.
  final String action;

  /// The id of what was acted on — a decision id, a live session id, a
  /// mission id.
  final String target;

  /// When the outcome was recorded, UTC.
  final DateTime occurredAt;

  final AuditResult result;

  /// Why a [AuditResult.failure] failed, in operator-facing words — the same
  /// message the screen showed. Null for success and cancelled. Redacted at
  /// the store boundary like [context].
  final String? failureReason;

  /// Relevant extra facts, already minimal by construction at each call site
  /// (flags like `commentProvided`, never the comment text itself — the
  /// feature's own record keeps content; this trail keeps the act) and
  /// redacted again at the store boundary as defense in depth
  /// (`audit_redaction.dart`).
  final Map<String, String> context;
}
