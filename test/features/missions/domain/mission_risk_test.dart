import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every risk level has a distinct, non-empty label', () {
    final Set<String> labels = MissionRisk.values
        .map((MissionRisk r) => r.label)
        .toSet();

    expect(labels, hasLength(MissionRisk.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
