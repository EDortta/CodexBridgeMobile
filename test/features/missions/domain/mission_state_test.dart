import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every state has a distinct, non-empty label', () {
    final Set<String> labels = MissionState.values
        .map((MissionState s) => s.label)
        .toSet();

    expect(labels, hasLength(MissionState.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
