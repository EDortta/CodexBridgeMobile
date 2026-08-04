import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_decision_repository.dart';
import '../domain/decision.dart';
import '../domain/decision_repository.dart';

final Provider<DecisionRepository> decisionRepositoryProvider =
    Provider<DecisionRepository>((Ref ref) => MockDecisionRepository());

final FutureProvider<List<Decision>> pendingDecisionsProvider =
    FutureProvider<List<Decision>>((Ref ref) async {
      return ref.watch(decisionRepositoryProvider).loadPendingDecisions();
    });
