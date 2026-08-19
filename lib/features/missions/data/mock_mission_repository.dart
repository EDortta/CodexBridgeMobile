import '../domain/mission.dart';
import '../domain/mission_repository.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_stage.dart';
import '../domain/mission_state.dart';

/// Stands in for a real missions endpoint until one exists — same "fake
/// until the contract exists" shape `MockProjectRepository` uses, tagged
/// with the same project ids so #24's dashboard has real cross-project data
/// to filter. `codex-bridge-cli` deliberately has no mission, so the
/// dashboard's "no active mission" empty state has something real to
/// render. `id`, `projectId`, `title` and `status` on the first three
/// fixtures are exactly what #24's and #27's own tests pin — only new
/// fields were added to them.
class MockMissionRepository implements MissionRepository {
  @override
  Future<List<Mission>> loadMissions() {
    return Future<List<Mission>>.value(<Mission>[
      Mission(
        id: 'mobile-foundation',
        projectId: 'codex-bridge-mobile',
        title: 'Codex Bridge Mobile',
        status: 'Local foundation active',
        stage: MissionStage.documentation,
        risk: MissionRisk.low,
        state: MissionState.active,
        owner: 'Claude',
        progress: 0.85,
        startedAt: DateTime.utc(2026, 8, 3),
        latestEvent: 'Docs updated for #26',
      ),
      Mission(
        id: 'fix-development-build',
        projectId: 'codex-bridge',
        title: 'Fix the failing development build',
        status: 'Investigating',
        stage: MissionStage.implementation,
        risk: MissionRisk.high,
        state: MissionState.blocked,
        owner: 'Claude',
        progress: 0.4,
        startedAt: DateTime.utc(2026, 8, 18, 22),
        latestEvent: 'CI still failing on the integration test suite',
        blockedReason: 'Waiting on infra to restore the CI runner.',
      ),
      Mission(
        id: 'desktop-shell-review',
        projectId: 'codex-bridge-desktop',
        title: 'Desktop shell review',
        status: 'Awaiting review',
        stage: MissionStage.validation,
        risk: MissionRisk.medium,
        state: MissionState.paused,
        owner: 'Claude',
        progress: 0.6,
        startedAt: DateTime.utc(2026, 8, 16),
        latestEvent: 'Paused pending design sign-off',
      ),
      Mission(
        id: 'bridge-ci-pipeline-upgrade',
        projectId: 'codex-bridge',
        title: 'Upgrade the CI pipeline runner image',
        status: 'Completed',
        stage: MissionStage.documentation,
        risk: MissionRisk.low,
        state: MissionState.completed,
        owner: 'Claude',
        progress: 1,
        startedAt: DateTime.utc(2026, 8, 12),
        latestEvent: 'Rollout notes published',
      ),
    ]);
  }
}
