import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every urgency has a distinct, non-empty label', () {
    final Set<String> labels = DecisionUrgency.values
        .map((DecisionUrgency u) => u.label)
        .toSet();

    expect(labels, hasLength(DecisionUrgency.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
