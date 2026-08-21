import '../domain/epic.dart';
import '../domain/issue_repository.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';

/// Stands in for a real epics/issues endpoint until one exists —
/// CodexBridge #8 ("Expose Epics and Issues API") is open, not implemented
/// (`gh issue view 8 -R EDortta/CodexBridge`, checked 2026-08-21), so
/// `HttpIssueRepository` cannot be wired yet. Its proposed scope names the
/// same fields #29 needed: "Status, priority, labels, assignee, dependencies
/// and blocked reasons" and "Epic–Issue relationships" — `ProjectIssue`'s
/// and `Epic`'s new fields follow that shape directly, the same way #27
/// shaped `Mission`'s fields off CodexBridge #7's proposed scope.
///
/// The four issues this mock carried before #29 (`fix-development-build`,
/// `flaky-connection-test`, `desktop-shortcut-conflict`,
/// `mobile-icon-polish`) keep their exact `id`/`title`/`priority`/
/// `projectId` — `project_dashboard_screen.dart`'s "Priority issues" section
/// (#24) and its tests read those four fields and nothing else, so #29 only
/// *adds* fields to them. `codex-bridge-cli` deliberately carries no issue
/// or epic — `project_dashboard_screen_test.dart` pins its "No open issues
/// for this project." empty state.
class MockIssueRepository implements IssueRepository {
  MockIssueRepository()
    : _epics = <String, Epic>{for (final Epic epic in _seedEpics()) epic.id: epic},
      _issues = <String, ProjectIssue>{
        for (final ProjectIssue issue in _seedIssues()) issue.id: issue,
      };

  final Map<String, Epic> _epics;
  final Map<String, ProjectIssue> _issues;

  @override
  Future<List<ProjectIssue>> loadIssues() async =>
      _issues.values.toList(growable: false);

  @override
  Future<List<Epic>> loadEpics() async => _epics.values.toList(growable: false);

  @override
  Future<ProjectIssue> loadIssue(String issueId) async {
    final ProjectIssue? issue = _issues[issueId];
    if (issue == null) {
      throw IssueNotFoundException(issueId);
    }
    return issue;
  }

  @override
  Future<Epic> loadEpic(String epicId) async {
    final Epic? epic = _epics[epicId];
    if (epic == null) {
      throw EpicNotFoundException(epicId);
    }
    return epic;
  }

  static List<Epic> _seedEpics() => <Epic>[
    Epic(
      id: 'epic-mobile-planning',
      projectId: 'codex-bridge-mobile',
      title: 'Epic 06 — Epics, Issues e planejamento',
      status: IssueStatus.inProgress,
      priority: IssuePriority.high,
      createdAt: DateTime.utc(2026, 8, 3),
      summary:
          'Bring epics and issues into the mobile terminal so planning work '
          'is visible from the field, not just the CodexBridge web console.',
      issueIds: const <String>['issue-epics-browser', 'issue-issue-detail'],
    ),
    Epic(
      id: 'epic-backend-contract',
      projectId: 'codex-bridge',
      title: 'Epic 01 — Mobile API foundation',
      status: IssueStatus.blocked,
      priority: IssuePriority.critical,
      createdAt: DateTime.utc(2026, 8, 10),
      summary:
          'Every mobile-consumed endpoint the gateway exposes — auth, '
          'sessions, projects, decisions, missions, epics and issues.',
      blockedReason: 'Waiting on operator review of the gh-5/6/7/8 integration merge.',
      issueIds: const <String>[
        'fix-development-build',
        'flaky-connection-test',
        'issue-migration-collision',
      ],
    ),
    Epic(
      id: 'epic-desktop-shell',
      projectId: 'codex-bridge-desktop',
      title: 'Epic 02 — Desktop shell parity',
      status: IssueStatus.done,
      priority: IssuePriority.normal,
      createdAt: DateTime.utc(2026, 8, 1),
      summary: 'Bring the desktop shell to feature parity with the CLI.',
      issueIds: const <String>['desktop-shortcut-conflict'],
    ),
  ];

  static List<ProjectIssue> _seedIssues() => <ProjectIssue>[
    ProjectIssue(
      id: 'fix-development-build',
      projectId: 'codex-bridge',
      epicId: 'epic-backend-contract',
      title: 'Development build fails on the CI runner',
      priority: IssuePriority.critical,
      status: IssueStatus.blocked,
      assignee: 'Claude',
      createdAt: DateTime.utc(2026, 8, 18),
      summary: 'The CI runner cannot build development — blocks every other merge.',
      blockedReason: 'Waiting on operator review of the gh-5/6/7/8 integration merge.',
      labels: const <String>['ci', 'backend'],
      dependencies: const <String>['gh-5/6/7/8 integration merge'],
    ),
    ProjectIssue(
      id: 'flaky-connection-test',
      projectId: 'codex-bridge',
      epicId: 'epic-backend-contract',
      title: 'Connection test is flaky under load',
      priority: IssuePriority.high,
      status: IssueStatus.inProgress,
      assignee: 'Claude',
      createdAt: DateTime.utc(2026, 8, 15),
      summary: 'Intermittent timeouts under concurrent load in the connection test suite.',
      labels: const <String>['backend', 'testing'],
    ),
    ProjectIssue(
      id: 'issue-migration-collision',
      projectId: 'codex-bridge',
      epicId: 'epic-backend-contract',
      title: 'Renumber the colliding 0005 migrations',
      priority: IssuePriority.critical,
      status: IssueStatus.blocked,
      assignee: 'Claude',
      createdAt: DateTime.utc(2026, 8, 19),
      summary:
          '#6 and #8 each independently claimed migrations/0005_*.sql — resolved by '
          'renumbering #8 to 0006 during the integration merge.',
      blockedReason: 'Waiting on operator review of the integration branch.',
      dependencies: const <String>['Expose Epics and Issues API (CodexBridge #8)'],
    ),
    ProjectIssue(
      id: 'desktop-shortcut-conflict',
      projectId: 'codex-bridge-desktop',
      epicId: 'epic-desktop-shell',
      title: 'Keyboard shortcut conflicts with the OS',
      priority: IssuePriority.normal,
      status: IssueStatus.todo,
      createdAt: DateTime.utc(2026, 8, 12),
      summary: 'The save-artifact shortcut collides with a reserved OS binding.',
      labels: const <String>['desktop'],
    ),
    ProjectIssue(
      id: 'mobile-icon-polish',
      projectId: 'codex-bridge-mobile',
      title: 'App icon needs a higher-resolution asset',
      priority: IssuePriority.low,
      status: IssueStatus.done,
      assignee: 'Claude',
      createdAt: DateTime.utc(2026, 7, 30),
      summary: 'Small visual fix, already shipped.',
      labels: const <String>['mobile', 'design'],
    ),
    ProjectIssue(
      id: 'issue-epics-browser',
      projectId: 'codex-bridge-mobile',
      epicId: 'epic-mobile-planning',
      title: 'Build Epics and Issues browser',
      priority: IssuePriority.high,
      status: IssueStatus.inProgress,
      assignee: 'Claude',
      createdAt: DateTime.utc(2026, 8, 20),
      summary:
          'Project-scoped lists with status, priority, labels, dependencies, '
          'assignee and blocked indicators; distinct Epic and Issue views.',
      labels: const <String>['mobile', 'planning'],
      dependencies: const <String>['Mission detail, timeline and controls (#28)'],
    ),
    ProjectIssue(
      id: 'issue-issue-detail',
      projectId: 'codex-bridge-mobile',
      epicId: 'epic-mobile-planning',
      title: 'Issue creation, editing and planning review',
      priority: IssuePriority.normal,
      status: IssueStatus.todo,
      createdAt: DateTime.utc(2026, 8, 20),
      summary: 'Let the operator create and edit issues from the mobile app.',
    ),
  ];
}
