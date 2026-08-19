import 'package:codex_bridge_mobile/features/projects/domain/project_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every health value has a distinct, non-empty label', () {
    final Set<String> labels = ProjectHealth.values
        .map((ProjectHealth h) => h.label)
        .toSet();

    expect(labels, hasLength(ProjectHealth.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
