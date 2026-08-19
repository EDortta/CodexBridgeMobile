import 'decision_audit_event.dart';
import 'decision_comment.dart';
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
    this.context = '',
    this.riskDetails = const <String>[],
    this.evidence = const <String>[],
    this.affectedEntities = const <String>[],
    this.discussion = const <DecisionComment>[],
    this.auditTrail = const <DecisionAuditEvent>[],
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

  /// A short summary of what resolving this decision affects — the inbox
  /// card's own line (#25).
  final String impactSummary;

  /// A short summary of the agent's own recommendation, if it made one.
  final String recommendationSummary;

  /// The longer situation the operator needs before deciding — issue #26's
  /// "context". Empty for a decision only ever seen through the inbox card.
  final String context;

  /// Specific risk narratives — distinct from [risk], which is only a
  /// severity level. Named separately so "risk" (the enum) and "risks" (this
  /// list) cannot be confused for one field.
  final List<String> riskDetails;
  final List<String> evidence;
  final List<String> affectedEntities;

  /// Free-form conversation — the "discuss" action. Never changes [state].
  final List<DecisionComment> discussion;

  /// The formal resolution record — approve/reject/request-revision, each
  /// appended by the action that produced it. See `DecisionAuditEvent`'s own
  /// doc comment for how this differs from [discussion].
  final List<DecisionAuditEvent> auditTrail;

  Decision copyWith({
    DecisionState? state,
    List<DecisionComment>? discussion,
    List<DecisionAuditEvent>? auditTrail,
  }) {
    return Decision(
      id: id,
      projectId: projectId,
      title: title,
      requestedBy: requestedBy,
      requestedAt: requestedAt,
      urgency: urgency,
      risk: risk,
      state: state ?? this.state,
      deadline: deadline,
      impactSummary: impactSummary,
      recommendationSummary: recommendationSummary,
      context: context,
      riskDetails: riskDetails,
      evidence: evidence,
      affectedEntities: affectedEntities,
      discussion: discussion ?? this.discussion,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }
}
