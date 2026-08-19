/// What happened to a [Decision] — issue #26's "all outcomes create an audit
/// event" acceptance criterion. Scoped to this feature's own resolution
/// actions; the cross-cutting, immutable audit *store* (redaction, session
/// controls, file access, installation flows) is issue #46's job
/// (`docs/issues/phase-3/RESUME.md`), not built here.
enum DecisionAuditAction {
  approved,
  rejected,
  revisionRequested;

  String get label => switch (this) {
    DecisionAuditAction.approved => 'Approved',
    DecisionAuditAction.rejected => 'Rejected',
    DecisionAuditAction.revisionRequested => 'Revision requested',
  };
}

class DecisionAuditEvent {
  const DecisionAuditEvent({
    required this.id,
    required this.action,
    required this.actor,
    required this.occurredAt,
    this.comment,
  });

  final String id;
  final DecisionAuditAction action;
  final String actor;
  final DateTime occurredAt;

  /// The rejection justification or revision comment, when the action
  /// carried one. Null for an approval with no comment.
  final String? comment;
}
