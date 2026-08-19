import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Mission missionWith({
    String id = 'm',
    String projectId = 'p',
    MissionStage stage = MissionStage.implementation,
    MissionRisk risk = MissionRisk.low,
    MissionState state = MissionState.active,
  }) {
    return Mission(
      id: id,
      projectId: projectId,
      title: 'Title $id',
      status: 'Status',
      stage: stage,
      risk: risk,
      state: state,
      owner: 'Claude',
      progress: 0.5,
      startedAt: DateTime.utc(2026, 8, 15, 9),
      latestEvent: 'Event',
    );
  }

  final Mission blocked = missionWith(
    id: 'blocked',
    projectId: 'a',
    stage: MissionStage.testing,
    risk: MissionRisk.high,
    state: MissionState.blocked,
  );
  final Mission routine = missionWith(
    id: 'routine',
    projectId: 'b',
    stage: MissionStage.planning,
    risk: MissionRisk.low,
    state: MissionState.active,
  );
  final List<Mission> all = <Mission>[blocked, routine];

  test('no filters returns everything', () {
    expect(
      filterMissions(all, projectId: null, stage: null, risk: null, state: null),
      all,
    );
  });

  test('a stage filter keeps only that stage', () {
    expect(
      filterMissions(
        all,
        projectId: null,
        stage: MissionStage.testing,
        risk: null,
        state: null,
      ),
      <Mission>[blocked],
    );
  });

  test('a state filter keeps only that state', () {
    expect(
      filterMissions(
        all,
        projectId: null,
        stage: null,
        risk: null,
        state: MissionState.blocked,
      ),
      <Mission>[blocked],
    );
  });

  test('project and risk filters combine (AND, not OR)', () {
    expect(
      filterMissions(
        all,
        projectId: 'b',
        stage: null,
        risk: MissionRisk.high,
        state: null,
      ),
      isEmpty,
    );
  });
}
