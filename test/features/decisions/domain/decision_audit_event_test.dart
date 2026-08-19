import 'package:codex_bridge_mobile/features/decisions/domain/decision_audit_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every audit action has a distinct, non-empty label', () {
    final Set<String> labels = DecisionAuditAction.values
        .map((DecisionAuditAction a) => a.label)
        .toSet();

    expect(labels, hasLength(DecisionAuditAction.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });

  test('fields round-trip through the constructor', () {
    final DateTime occurredAt = DateTime.utc(2026, 8, 19, 12);
    final DecisionAuditEvent event = DecisionAuditEvent(
      id: 'e-1',
      action: DecisionAuditAction.rejected,
      actor: 'You',
      occurredAt: occurredAt,
      comment: 'Not safe enough.',
    );

    expect(event.action, DecisionAuditAction.rejected);
    expect(event.actor, 'You');
    expect(event.occurredAt, occurredAt);
    expect(event.comment, 'Not safe enough.');
  });

  test('comment defaults to null for an approval with none', () {
    final DecisionAuditEvent event = DecisionAuditEvent(
      id: 'e-2',
      action: DecisionAuditAction.approved,
      actor: 'You',
      occurredAt: DateTime.utc(2026, 8, 19, 12),
    );

    expect(event.comment, isNull);
  });
}
