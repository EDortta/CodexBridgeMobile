import 'package:codex_bridge_mobile/features/missions/domain/mission_control_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only cancel requires confirmation — pause and resume are reversible', () {
    expect(MissionControlAction.pause.requiresConfirmation, isFalse);
    expect(MissionControlAction.resume.requiresConfirmation, isFalse);
    expect(MissionControlAction.cancel.requiresConfirmation, isTrue);
  });

  test('every action has a distinct, human label', () {
    final Set<String> labels = MissionControlAction.values
        .map((MissionControlAction a) => a.label)
        .toSet();

    expect(labels, hasLength(MissionControlAction.values.length));
  });
}
