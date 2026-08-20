/// A single transition recorded on a [Mission]'s timeline — issue #28's own
/// acceptance criterion: "o histórico registra toda transição relevante."
///
/// Distinct from `Mission.latestEvent` (#27), which is a one-line free-text
/// summary the missions list card shows verbatim: [MissionTimelineEvent] is
/// the structured, append-only record the detail screen's timeline renders,
/// the same "summary field vs. structured history" split
/// `Decision.impactSummary` vs. `DecisionAuditEvent` already draws.
class MissionTimelineEvent {
  const MissionTimelineEvent({
    required this.id,
    required this.description,
    required this.actor,
    required this.occurredAt,
  });

  final String id;

  /// What happened, in plain language — e.g. "Mission started", "Paused by
  /// You", "Blocked: waiting on infra.".
  final String description;

  /// Who caused this transition — the mission's [Mission.owner] for agent
  /// progress, `"You"` for an operator control action.
  final String actor;

  final DateTime occurredAt;
}
