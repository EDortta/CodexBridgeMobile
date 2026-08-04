import 'decision.dart';

abstract interface class DecisionRepository {
  Future<List<Decision>> loadPendingDecisions();
}
