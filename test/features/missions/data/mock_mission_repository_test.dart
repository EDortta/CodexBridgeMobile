import 'package:codex_bridge_mobile/features/missions/data/mock_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no duplicate ids, and codex-bridge-cli has no mission', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    expect(
      missions.map((Mission m) => m.id).toSet(),
      hasLength(missions.length),
    );
    expect(
      missions.any((Mission m) => m.projectId == 'codex-bridge-cli'),
      isFalse,
      reason: "the dashboard's no-active-mission empty state needs a project with none",
    );
  });

  test('at least one mission is blocked, so the state filter has something to exclude', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    expect(missions.any((Mission m) => m.state == MissionState.blocked), isTrue);
  });

  test('a blocked mission needs intervention and carries a reason', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission blocked = missions.firstWhere(
      (Mission m) => m.state == MissionState.blocked,
    );

    expect(blocked.needsIntervention, isTrue);
    expect(blocked.blockedReason, isNotNull);
    expect(blocked.blockedReason, isNotEmpty);
  });

  test('the mobile-foundation fixture keeps the exact id/status #24 and #27 pin', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission mobile = missions.firstWhere((Mission m) => m.id == 'mobile-foundation');

    expect(mobile.status, 'Local foundation active');
  });

  test('the desktop-shell-review fixture keeps the exact title #24 pins', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission desktop = missions.firstWhere(
      (Mission m) => m.id == 'desktop-shell-review',
    );

    expect(desktop.title, 'Desktop shell review');
  });
}
