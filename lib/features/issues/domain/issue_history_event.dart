/// A single recorded change on a [ProjectIssue] — issue #30's "changes
/// preserve history" acceptance criterion.
///
/// Same "structured, append-only record" shape `MissionTimelineEvent`
/// (`features/missions/`) and `DecisionAuditEvent` (`features/decisions/`)
/// already use for their own entities, kept separate from those types for
/// the same reason `MissionTimelineEvent`'s doc comment gives: a feature
/// must never import another feature's domain
/// (`docs/architecture/state-architecture.md`).
class IssueHistoryEvent {
  const IssueHistoryEvent({
    required this.id,
    required this.description,
    required this.actor,
    required this.occurredAt,
  });

  final String id;

  /// What changed, in plain language — e.g. "Priority changed from High to
  /// Critical.", "Status changed to Blocked.".
  final String description;

  /// Who made this change — `'You'` for the signed-in operator, the same
  /// convention `MissionTimelineEvent.actor` uses for an operator control
  /// action.
  final String actor;

  final DateTime occurredAt;
}
