import 'package:codex_bridge_mobile/features/decisions/data/mock_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_audit_event.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_repository.dart';
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

  test('loadDecision throws for an unknown id', () {
    expect(
      MockDecisionRepository().loadDecision('does-not-exist'),
      throwsA(isA<DecisionNotFoundException>()),
    );
  });

  test('approve resolves the decision and appends an audit event', () async {
    final MockDecisionRepository repository = MockDecisionRepository(
      clock: () => DateTime.utc(2026, 8, 19, 12),
    );

    final Decision approved = await repository.approve(
      'shell-review',
      comment: 'Looks good.',
    );

    expect(approved.state, DecisionState.approved);
    expect(approved.auditTrail, hasLength(1));
    expect(approved.auditTrail.single.action, DecisionAuditAction.approved);
    expect(approved.auditTrail.single.comment, 'Looks good.');
    expect(approved.auditTrail.single.occurredAt, DateTime.utc(2026, 8, 19, 12));
  });

  test('a resolution mutation sticks: loadDecision sees it afterward', () async {
    final MockDecisionRepository repository = MockDecisionRepository();

    await repository.approve('shell-review');
    final Decision reloaded = await repository.loadDecision('shell-review');

    expect(reloaded.state, DecisionState.approved);
  });

  test('reject requires a non-empty justification', () {
    final MockDecisionRepository repository = MockDecisionRepository();

    expect(
      repository.reject('shell-review', justification: ''),
      throwsArgumentError,
    );
    expect(
      repository.reject('shell-review', justification: '   '),
      throwsArgumentError,
    );
  });

  test('reject with a justification resolves as rejected', () async {
    final MockDecisionRepository repository = MockDecisionRepository();

    final Decision rejected = await repository.reject(
      'shell-review',
      justification: 'Not ready yet.',
    );

    expect(rejected.state, DecisionState.rejected);
    expect(rejected.auditTrail.single.comment, 'Not ready yet.');
  });

  test('requestRevision requires a non-empty comment', () {
    final MockDecisionRepository repository = MockDecisionRepository();

    expect(
      repository.requestRevision('shell-review', comment: ''),
      throwsArgumentError,
    );
  });

  test('discuss requires a non-empty comment and does not change state', () async {
    final MockDecisionRepository repository = MockDecisionRepository();

    expect(
      repository.discuss('shell-review', comment: ''),
      throwsArgumentError,
    );

    final Decision discussed = await repository.discuss(
      'shell-review',
      comment: 'Can we get another reviewer?',
    );

    expect(discussed.state, DecisionState.pending);
    expect(discussed.discussion, hasLength(1));
    expect(discussed.discussion.single.body, 'Can we get another reviewer?');
    expect(discussed.discussion.single.author, isNotEmpty);
  });

  test('discuss does not add an audit event — only resolution actions do', () async {
    final MockDecisionRepository repository = MockDecisionRepository();

    final Decision discussed = await repository.discuss(
      'shell-review',
      comment: 'Just a comment.',
    );

    expect(discussed.auditTrail, isEmpty);
  });
}
