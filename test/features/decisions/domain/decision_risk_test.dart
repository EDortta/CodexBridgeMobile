import 'package:codex_bridge_mobile/features/decisions/domain/decision_risk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every risk level has a distinct, non-empty label', () {
    final Set<String> labels = DecisionRisk.values
        .map((DecisionRisk r) => r.label)
        .toSet();

    expect(labels, hasLength(DecisionRisk.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
