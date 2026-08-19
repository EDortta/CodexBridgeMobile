import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Mission missionWith({
    MissionState state = MissionState.active,
    String? blockedReason,
  }) {
    return Mission(
      id: 'm-1',
      projectId: 'codex-bridge-mobile',
      title: 'Title',
      status: 'Status',
      stage: MissionStage.implementation,
      risk: MissionRisk.medium,
      state: state,
      owner: 'Claude',
      progress: 0.5,
      startedAt: DateTime.utc(2026, 8, 15, 9),
      latestEvent: 'Something happened',
      blockedReason: blockedReason,
    );
  }

  test('every field round-trips through the constructor', () {
    final Mission mission = missionWith();

    expect(mission.projectId, 'codex-bridge-mobile');
    expect(mission.stage, MissionStage.implementation);
    expect(mission.risk, MissionRisk.medium);
    expect(mission.state, MissionState.active);
    expect(mission.owner, 'Claude');
    expect(mission.progress, 0.5);
    expect(mission.startedAt, DateTime.utc(2026, 8, 15, 9));
    expect(mission.latestEvent, 'Something happened');
  });

  group('needsIntervention', () {
    test('is true when blocked', () {
      expect(missionWith(state: MissionState.blocked).needsIntervention, isTrue);
    });

    test('is false for every other state', () {
      for (final MissionState state in MissionState.values) {
        if (state == MissionState.blocked) {
          continue;
        }
        expect(
          missionWith(state: state).needsIntervention,
          isFalse,
          reason: '$state should not need intervention',
        );
      }
    });
  });
}
