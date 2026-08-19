import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every priority has a distinct, non-empty label', () {
    final Set<String> labels = IssuePriority.values
        .map((IssuePriority p) => p.label)
        .toSet();

    expect(labels, hasLength(IssuePriority.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
