import '../domain/issue_repository.dart';
import '../domain/project_issue.dart';

/// Stands in for a real issues endpoint until one exists — CodexBridge #8
/// ("Expose Epics and Issues API") is still open. Same "fake until the
/// contract exists" shape `MockProjectRepository` uses, tagged with the same
/// project ids as the mock projects. `codex-bridge` (the `unhealthy`
/// project, whose card already reads "Build failing on development")
/// carries a critical issue for narrative consistency with that mock data.
class MockIssueRepository implements IssueRepository {
  @override
  Future<List<ProjectIssue>> loadIssues() {
    return Future<List<ProjectIssue>>.value(const <ProjectIssue>[
      ProjectIssue(
        id: 'fix-development-build',
        projectId: 'codex-bridge',
        title: 'Development build fails on the CI runner',
        priority: IssuePriority.critical,
      ),
      ProjectIssue(
        id: 'flaky-connection-test',
        projectId: 'codex-bridge',
        title: 'Connection test is flaky under load',
        priority: IssuePriority.high,
      ),
      ProjectIssue(
        id: 'desktop-shortcut-conflict',
        projectId: 'codex-bridge-desktop',
        title: 'Keyboard shortcut conflicts with the OS',
        priority: IssuePriority.normal,
      ),
      ProjectIssue(
        id: 'mobile-icon-polish',
        projectId: 'codex-bridge-mobile',
        title: 'App icon needs a higher-resolution asset',
        priority: IssuePriority.low,
      ),
    ]);
  }
}
