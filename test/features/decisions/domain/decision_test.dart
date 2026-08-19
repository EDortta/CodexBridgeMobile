import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_audit_event.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_comment.dart';
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

  group('copyWith', () {
    final Decision base = Decision(
      id: 'd-1',
      projectId: 'codex-bridge-desktop',
      title: 'Title',
      requestedBy: 'Someone',
      requestedAt: DateTime.utc(2026, 8, 15, 9),
      urgency: DecisionUrgency.normal,
      risk: DecisionRisk.low,
      state: DecisionState.pending,
      deadline: DateTime.utc(2026, 8, 20),
      impactSummary: 'Impact',
      recommendationSummary: 'Recommendation',
    );

    test('with no arguments returns an equivalent decision', () {
      final Decision copy = base.copyWith();

      expect(copy.state, base.state);
      expect(copy.discussion, base.discussion);
      expect(copy.auditTrail, base.auditTrail);
    });

    test('changes only the fields given', () {
      final Decision resolved = base.copyWith(state: DecisionState.approved);

      expect(resolved.state, DecisionState.approved);
      expect(resolved.title, base.title);
      expect(resolved.discussion, base.discussion);
    });

    test('appends to discussion and auditTrail without mutating the original', () {
      final DecisionComment comment = DecisionComment(
        id: 'c-1',
        author: 'You',
        body: 'Looks fine.',
        postedAt: DateTime.utc(2026, 8, 19, 12),
      );
      final DecisionAuditEvent event = DecisionAuditEvent(
        id: 'e-1',
        action: DecisionAuditAction.approved,
        actor: 'You',
        occurredAt: DateTime.utc(2026, 8, 19, 12),
      );

      final Decision updated = base.copyWith(
        discussion: <DecisionComment>[...base.discussion, comment],
        auditTrail: <DecisionAuditEvent>[...base.auditTrail, event],
      );

      expect(updated.discussion, <DecisionComment>[comment]);
      expect(updated.auditTrail, <DecisionAuditEvent>[event]);
      expect(base.discussion, isEmpty);
      expect(base.auditTrail, isEmpty);
    });
  });
}
