import '../domain/project_repository.dart';
import '../domain/project_summary.dart';

class MockProjectRepository implements ProjectRepository {
  @override
  Future<List<ProjectSummary>> loadProjects() {
    return Future<List<ProjectSummary>>.value(const <ProjectSummary>[
      ProjectSummary(
        id: 'codex-bridge-mobile',
        name: 'Codex Bridge Mobile',
        status: 'Foundation phase',
      ),
      ProjectSummary(
        id: 'codex-bridge-desktop',
        name: 'Codex Bridge Desktop',
        status: 'Awaiting review',
      ),
    ]);
  }
}
