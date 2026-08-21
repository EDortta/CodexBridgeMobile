import 'decision.dart';

/// Thrown when a decision id has no matching record.
class DecisionNotFoundException implements Exception {
  const DecisionNotFoundException(this.decisionId);

  final String decisionId;

  @override
  String toString() => 'No decision found with id "$decisionId".';
}

/// A decisions call failed for a reason the operator can be told about —
/// unreachable server, malformed response, an unsupported action, or a
/// resolution the gateway refused for a reason other than a conflict. Never
/// thrown for a missing decision (see [DecisionNotFoundException]) or a
/// concurrency conflict (see [DecisionConflictException]) — those get their
/// own type so a caller can tell them apart without parsing [message].
class DecisionRepositoryException implements Exception {
  const DecisionRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when `approve`/`reject`/`requestRevision` could not apply because
/// the decision changed on the server since this device last read it.
///
/// Covers two distinct server responses that mean the same thing to the
/// operator — "re-read this decision and decide again" — so a caller only
/// has to handle one type:
/// - HTTP 412: this device's `If-Match` no longer names the decision's
///   current revision (RFC 9110 §13.1.1 — a stale write).
/// - HTTP 409: the decision already left `pending` by the time the write
///   reached the server (approved/rejected/revision-requested by another
///   device, or otherwise no longer decidable).
///
/// `gateway/app/api/routes/decisions.py`'s `_resolve` checks `If-Match`
/// before the state, so 412 is the far more common of the two in practice —
/// but neither is ever retried automatically here; the caller decides what
/// "decide again" means for the operator.
class DecisionConflictException implements Exception {
  const DecisionConflictException(this.message);

  final String message;

  @override
  String toString() => message;
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
