import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every state has a distinct, non-empty label', () {
    final Set<String> labels = DecisionState.values
        .map((DecisionState s) => s.label)
        .toSet();

    expect(labels, hasLength(DecisionState.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
