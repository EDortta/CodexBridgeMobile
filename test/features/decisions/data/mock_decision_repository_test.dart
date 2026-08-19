import 'package:codex_bridge_mobile/features/decisions/data/mock_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no duplicate ids, and both pending and resolved states are represented', () async {
    final List<Decision> decisions = await MockDecisionRepository().loadDecisions();

    expect(
      decisions.map((Decision d) => d.id).toSet(),
      hasLength(decisions.length),
    );
    expect(
      decisions.any((Decision d) => d.state == DecisionState.pending),
      isTrue,
    );
    expect(
      decisions.any((Decision d) => d.state != DecisionState.pending),
      isTrue,
      reason: 'the state filter needs at least one resolved decision to exclude',
    );
  });

  test('codex-bridge-desktop keeps exactly the 2 pending decisions #24 pins', () async {
    final List<Decision> decisions = await MockDecisionRepository().loadDecisions();

    final List<Decision> desktopPending = decisions
        .where(
          (Decision d) =>
              d.projectId == 'codex-bridge-desktop' &&
              d.state == DecisionState.pending,
        )
        .toList();

    expect(desktopPending, hasLength(2));
  });

  test('at least one decision is critical urgency', () async {
    final List<Decision> decisions = await MockDecisionRepository().loadDecisions();

    expect(
      decisions.any((Decision d) => d.urgency == DecisionUrgency.critical),
      isTrue,
    );
  });
}
