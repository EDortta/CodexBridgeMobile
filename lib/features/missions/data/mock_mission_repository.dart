import '../domain/mission.dart';
import '../domain/mission_repository.dart';

/// Stands in for a real missions endpoint until one exists — same "fake
/// until the contract exists" shape `MockProjectRepository` uses, tagged
/// with the same project ids so #24's dashboard has real cross-project data
/// to filter. `codex-bridge-cli` deliberately has no mission, so the
/// dashboard's "no active mission" empty state has something real to render.
class MockMissionRepository implements MissionRepository {
  @override
  Future<List<Mission>> loadMissions() {
    return Future<List<Mission>>.value(const <Mission>[
      Mission(
        id: 'mobile-foundation',
        projectId: 'codex-bridge-mobile',
        title: 'Codex Bridge Mobile',
        status: 'Local foundation active',
      ),
      Mission(
        id: 'fix-development-build',
        projectId: 'codex-bridge',
        title: 'Fix the failing development build',
        status: 'Investigating',
      ),
      Mission(
        id: 'desktop-shell-review',
        projectId: 'codex-bridge-desktop',
        title: 'Desktop shell review',
        status: 'Awaiting review',
      ),
    ]);
  }
}
