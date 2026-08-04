import '../domain/decision.dart';
import '../domain/decision_repository.dart';

class MockDecisionRepository implements DecisionRepository {
  @override
  Future<List<Decision>> loadPendingDecisions() {
    return Future<List<Decision>>.value(const <Decision>[
      Decision(
        id: 'shell-review',
        title: 'Approve the navigation shell',
        requestedBy: 'Foundation phase',
      ),
    ]);
  }
}
