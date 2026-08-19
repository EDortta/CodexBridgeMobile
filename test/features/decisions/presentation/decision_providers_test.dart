import 'package:codex_bridge_mobile/features/decisions/data/mock_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_risk.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_filter.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 12);

  Decision decisionWith({
    String id = 'd',
    String projectId = 'p',
    DecisionUrgency urgency = DecisionUrgency.normal,
    DecisionRisk risk = DecisionRisk.low,
    DecisionState state = DecisionState.pending,
    DateTime? deadline,
  }) {
    return Decision(
      id: id,
      projectId: projectId,
      title: 'Title $id',
      requestedBy: 'Someone',
      requestedAt: now,
      urgency: urgency,
      risk: risk,
      state: state,
      deadline: deadline ?? now.add(const Duration(days: 30)),
      impactSummary: 'Impact',
      recommendationSummary: 'Recommendation',
    );
  }

  group('filterDecisions', () {
    final Decision critical = decisionWith(
      id: 'critical',
      urgency: DecisionUrgency.critical,
      risk: DecisionRisk.high,
      projectId: 'a',
    );
    final Decision routine = decisionWith(
      id: 'routine',
      urgency: DecisionUrgency.low,
      risk: DecisionRisk.low,
      projectId: 'b',
      state: DecisionState.approved,
    );
    final List<Decision> all = <Decision>[critical, routine];

    test('no filters returns everything', () {
      expect(
        filterDecisions(
          all,
          urgency: null,
          risk: null,
          state: null,
          projectId: null,
          deadline: DecisionDeadlineFilter.all,
          now: now,
        ),
        all,
      );
    });

    test('an urgency filter keeps only that urgency', () {
      expect(
        filterDecisions(
          all,
          urgency: DecisionUrgency.critical,
          risk: null,
          state: null,
          projectId: null,
          deadline: DecisionDeadlineFilter.all,
          now: now,
        ),
        <Decision>[critical],
      );
    });

    test('urgency and project filters combine (AND, not OR)', () {
      expect(
        filterDecisions(
          all,
          urgency: DecisionUrgency.critical,
          risk: null,
          state: null,
          projectId: 'b',
          deadline: DecisionDeadlineFilter.all,
          now: now,
        ),
        isEmpty,
      );
    });

    test('a state filter keeps only that state', () {
      expect(
        filterDecisions(
          all,
          urgency: null,
          risk: null,
          state: DecisionState.approved,
          projectId: null,
          deadline: DecisionDeadlineFilter.all,
          now: now,
        ),
        <Decision>[routine],
      );
    });

    test('a deadline bucket filter keeps only matching decisions', () {
      final Decision overdue = decisionWith(
        id: 'overdue',
        deadline: now.subtract(const Duration(days: 1)),
      );
      final Decision farOut = decisionWith(
        id: 'far-out',
        deadline: now.add(const Duration(days: 30)),
      );

      expect(
        filterDecisions(
          <Decision>[overdue, farOut],
          urgency: null,
          risk: null,
          state: null,
          projectId: null,
          deadline: DecisionDeadlineFilter.overdue,
          now: now,
        ),
        <Decision>[overdue],
      );
    });
  });

  test('pendingDecisionsProvider narrows decisionsProvider to pending only', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        decisionRepositoryProvider.overrideWithValue(MockDecisionRepository()),
      ],
    );
    addTearDown(container.dispose);

    final List<Decision> all = await container.read(decisionsProvider.future);
    final List<Decision>? pending = container
        .read(pendingDecisionsProvider)
        .valueOrNull;

    expect(pending, isNotNull);
    expect(
      pending!.every((Decision d) => d.state == DecisionState.pending),
      isTrue,
    );
    expect(pending.length, lessThan(all.length));
  });
}
