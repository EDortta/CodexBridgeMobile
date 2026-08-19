import 'decision.dart';

abstract interface class DecisionRepository {
  /// Every decision regardless of [DecisionState] — the inbox (#25) filters
  /// client-side, and the dashboard's pending-decisions section
  /// (`pendingDecisionsProvider`) narrows to `DecisionState.pending`.
  Future<List<Decision>> loadDecisions();
}
