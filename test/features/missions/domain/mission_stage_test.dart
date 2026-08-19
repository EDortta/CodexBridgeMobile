import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every stage has a distinct, non-empty label', () {
    final Set<String> labels = MissionStage.values
        .map((MissionStage s) => s.label)
        .toSet();

    expect(labels, hasLength(MissionStage.values.length));
    expect(labels.every((String label) => label.isNotEmpty), isTrue);
  });
}
