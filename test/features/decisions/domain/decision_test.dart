import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_risk.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every field round-trips through the constructor', () {
    final DateTime requestedAt = DateTime.utc(2026, 8, 15, 9);
    final DateTime deadline = DateTime.utc(2026, 8, 20);
    final Decision decision = Decision(
      id: 'd-1',
      projectId: 'codex-bridge-desktop',
      title: 'Title',
      requestedBy: 'Someone',
      requestedAt: requestedAt,
      urgency: DecisionUrgency.critical,
      risk: DecisionRisk.high,
      state: DecisionState.pending,
      deadline: deadline,
      impactSummary: 'Impact',
      recommendationSummary: 'Recommendation',
    );

    expect(decision.projectId, 'codex-bridge-desktop');
    expect(decision.requestedAt, requestedAt);
    expect(decision.urgency, DecisionUrgency.critical);
    expect(decision.risk, DecisionRisk.high);
    expect(decision.state, DecisionState.pending);
    expect(decision.deadline, deadline);
    expect(decision.impactSummary, 'Impact');
    expect(decision.recommendationSummary, 'Recommendation');
  });
}
