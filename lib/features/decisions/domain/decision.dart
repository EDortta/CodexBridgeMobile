import 'decision_risk.dart';
import 'decision_state.dart';
import 'decision_urgency.dart';

class Decision {
  const Decision({
    required this.id,
    required this.projectId,
    required this.title,
    required this.requestedBy,
    required this.requestedAt,
    required this.urgency,
    required this.risk,
    required this.state,
    required this.deadline,
    required this.impactSummary,
    required this.recommendationSummary,
  });

  final String id;
  final String projectId;

  /// The request itself, in the operator's own words — issue #25 calls this
  /// "request" on the inbox card.
  final String title;
  final String requestedBy;

  /// When the decision was requested — the dashboard's pending-decisions
  /// section marks a decision stale (`RelativeMoment.isStale`) against this.
  final DateTime requestedAt;

  final DecisionUrgency urgency;
  final DecisionRisk risk;
  final DecisionState state;

  /// When a response is needed by — distinct from [requestedAt]. The
  /// inbox's deadline filter (#25) buckets against this.
  final DateTime deadline;

  /// A short summary of what resolving this decision affects.
  final String impactSummary;

  /// A short summary of the agent's own recommendation, if it made one.
  final String recommendationSummary;
}
