import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_decision_repository.dart';
import '../domain/decision.dart';
import '../domain/decision_repository.dart';
import '../domain/decision_risk.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';
import 'decision_filter.dart';

final Provider<DecisionRepository> decisionRepositoryProvider =
    Provider<DecisionRepository>((Ref ref) => MockDecisionRepository());

/// Every decision, every state — the inbox (#25) filters from this.
final FutureProvider<List<Decision>> decisionsProvider =
    FutureProvider<List<Decision>>((Ref ref) async {
      return ref.watch(decisionRepositoryProvider).loadDecisions();
    });

/// Only [DecisionState.pending] decisions — what the project dashboard's
/// (#24) pending-decisions section shows. Derived from [decisionsProvider]
/// rather than a second repository call, the same shape
/// `projectListProvider` (`features/projects/`) joins two providers with.
final Provider<AsyncValue<List<Decision>>> pendingDecisionsProvider =
    Provider<AsyncValue<List<Decision>>>((Ref ref) {
      return ref
          .watch(decisionsProvider)
          .whenData(
            (List<Decision> all) => all
                .where((Decision d) => d.state == DecisionState.pending)
                .toList(growable: false),
          );
    });

final StateProvider<DecisionUrgency?> decisionUrgencyFilterProvider =
    StateProvider<DecisionUrgency?>((Ref ref) => null);

final StateProvider<DecisionRisk?> decisionRiskFilterProvider =
    StateProvider<DecisionRisk?>((Ref ref) => null);

/// Defaults to `pending` — an inbox opens on what still needs the operator,
/// not the full history. `null` here means "every state" once the operator
/// picks it explicitly.
final StateProvider<DecisionState?> decisionStateFilterProvider =
    StateProvider<DecisionState?>((Ref ref) => DecisionState.pending);

final StateProvider<String?> decisionProjectFilterProvider =
    StateProvider<String?>((Ref ref) => null);

final StateProvider<DecisionDeadlineFilter> decisionDeadlineFilterProvider =
    StateProvider<DecisionDeadlineFilter>((Ref ref) => DecisionDeadlineFilter.all);

/// Pure so it is testable without pumping a widget, the same reasoning
/// `filterProjectListItems` (`features/projects/`) documents. Every axis is
/// independently optional and combines with AND, satisfying #25's "filters
/// can be combined."
List<Decision> filterDecisions(
  List<Decision> decisions, {
  required DecisionUrgency? urgency,
  required DecisionRisk? risk,
  required DecisionState? state,
  required String? projectId,
  required DecisionDeadlineFilter deadline,
  required DateTime now,
}) {
  return decisions.where((Decision decision) {
    if (urgency != null && decision.urgency != urgency) {
      return false;
    }
    if (risk != null && decision.risk != risk) {
      return false;
    }
    if (state != null && decision.state != state) {
      return false;
    }
    if (projectId != null && decision.projectId != projectId) {
      return false;
    }
    if (deadline != DecisionDeadlineFilter.all &&
        classifyDeadline(decision.deadline, now) != deadline) {
      return false;
    }
    return true;
  }).toList(growable: false);
}
