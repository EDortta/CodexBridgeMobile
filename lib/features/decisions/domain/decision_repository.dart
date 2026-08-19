import 'decision.dart';

/// Thrown when a decision id has no matching record.
class DecisionNotFoundException implements Exception {
  const DecisionNotFoundException(this.decisionId);

  final String decisionId;

  @override
  String toString() => 'No decision found with id "$decisionId".';
}

abstract interface class DecisionRepository {
  /// Every decision regardless of [DecisionState] — the inbox (#25) filters
  /// client-side, and the dashboard's pending-decisions section
  /// (`pendingDecisionsProvider`) narrows to `DecisionState.pending`.
  Future<List<Decision>> loadDecisions();

  /// A single decision with its full context, discussion and audit trail —
  /// throws [DecisionNotFoundException] if [decisionId] does not exist.
  Future<Decision> loadDecision(String decisionId);

  /// Resolves [decisionId] as approved. [comment] is optional — approval is
  /// the one resolution action issue #26's parent epic does not require a
  /// justification for.
  Future<Decision> approve(String decisionId, {String? comment});

  /// Resolves [decisionId] as rejected. [justification] must be non-empty —
  /// issue #26's own acceptance criterion.
  Future<Decision> reject(String decisionId, {required String justification});

  /// Resolves [decisionId] as needing revision. [comment] must be non-empty
  /// — a revision request with nothing to revise is not actionable.
  Future<Decision> requestRevision(
    String decisionId, {
    required String comment,
  });

  /// Appends a discussion comment without changing [Decision.state].
  /// [comment] must be non-empty.
  Future<Decision> discuss(String decisionId, {required String comment});
}
