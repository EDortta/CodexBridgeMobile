import '../domain/project_health.dart';
import '../domain/project_repository.dart';
import '../domain/project_summary.dart';

/// Stands in for `GET /api/v1/projects` until CodexBridge #5 ("Expose
/// projects and project operational summary API") is implemented upstream —
/// that backend issue is still open, so this repository has no real contract
/// to call yet (the same "fake until the contract exists" shape #21 and #22
/// used, `docs/issues/phase-1/README.md`).
///
/// Covers all four [ProjectHealth] values so the list, search, filter and
/// attention-visibility behavior added by #23 has something real to exercise
/// without a device.
class MockProjectRepository implements ProjectRepository {
  @override
  Future<List<ProjectSummary>> loadProjects() {
    return Future<List<ProjectSummary>>.value(const <ProjectSummary>[
      ProjectSummary(
        id: 'codex-bridge-mobile',
        name: 'Codex Bridge Mobile',
        health: ProjectHealth.active,
      ),
      ProjectSummary(
        id: 'codex-bridge',
        name: 'Codex Bridge',
        health: ProjectHealth.unhealthy,
        attentionSummary: 'Build failing on development',
      ),
      ProjectSummary(
        id: 'codex-bridge-desktop',
        name: 'Codex Bridge Desktop',
        health: ProjectHealth.pendingDecision,
        attentionSummary: '2 decisions waiting your review',
      ),
      ProjectSummary(
        id: 'codex-bridge-cli',
        name: 'Codex Bridge CLI',
        health: ProjectHealth.offline,
        attentionSummary: 'Last seen 3 days ago',
      ),
    ]);
  }
}
