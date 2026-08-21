import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every status has a distinct, non-empty label', () {
    final Set<String> labels = IssueStatus.values
        .map((IssueStatus s) => s.label)
        .toSet();

    expect(labels, hasLength(IssueStatus.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
