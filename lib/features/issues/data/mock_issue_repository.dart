import '../domain/epic.dart';
import '../domain/issue_change_summary.dart';
import '../domain/issue_history_event.dart';
import '../domain/issue_repository.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';

/// The debug-build default and widget-test fixture — `HttpIssueRepository`
/// (`data/http_issue_repository.dart`) is the real implementation, wired in
/// release builds by `lib/app/issue_repository_binding.dart`, the same
/// `MockAuthGateway`/`HttpAuthGateway` split `auth_gateway_binding.dart`
/// uses. `ProjectIssue`'s and `Epic`'s fields were originally shaped off
/// CodexBridge issue #8's *proposed* scope while #8 was still open; #8 has
/// since shipped (`gateway/app/api/routes/epics.py`, `.../issues.py`) with a
/// narrower, project-scoped contract than this mock's own "everything,
/// unscoped" shape — see `HttpIssueRepository`'s class doc for how that gap
/// is closed without reshaping #29's UI or this mock.
///
/// The four issues this mock carried before #29 (`fix-development-build`,
/// `flaky-connection-test`, `desktop-shortcut-conflict`,
/// `mobile-icon-polish`) keep their exact `id`/`title`/`priority`/
/// `projectId` — `project_dashboard_screen.dart`'s "Priority issues" section
/// (#24) and its tests read those four fields and nothing else, so #29 only
/// *adds* fields to them. `codex-bridge-cli` deliberately carries no issue
/// or epic — `project_dashboard_screen_test.dart` pins its "No open issues
/// for this project." empty state.
///
/// **Since #30**, this is also the write path exercised by the app in a
/// debug build: [createEpic], [createIssue], [updateIssue] and
/// [linkIssueToEpic] keep every seeded and created record in memory for the
/// lifetime of the process, the same "stateful across a session" shape
/// `MockMissionRepository` uses for `pause`/`resume`/`cancel`. Every method
/// body below runs to completion with no `await` between reading `_issues`/
/// `_epics` and writing them back — the same reasoning
/// `MockMissionRepository._applyGuarded`'s doc comment gives for why that
/// is enough to close the lost-update race #28's council pass caught: an
/// `async` function in Dart runs synchronously up to its first `await`, so
/// two back-to-back calls with no `await` in between never interleave.
class MockIssueRepository implements IssueRepository {
  MockIssueRepository({this._now = DateTime.now}) {
    for (final Epic epic in _seedEpics()) {
      _epics[epic.id] = epic;
    }
    for (final ProjectIssue issue in _seedIssues()) {
      _issues[issue.id] = issue;
    }
  }

  final DateTime Function() _now;

  final Map<String, Epic> _epics = <String, Epic>{};
  final Map<String, ProjectIssue> _issues = <String, ProjectIssue>{};

  int _nextEpicSuffix = 1;
  int _nextIssueSuffix = 1;

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

  @override
  Future<Epic> createEpic({
    required String projectId,
    required String title,
    String? description,
    IssueStatus? status,
  }) async {
    final String id = 'epic-mock-${_nextEpicSuffix++}';
    final Epic epic = Epic(
      id: id,
      projectId: projectId,
      title: title,
      status: status ?? IssueStatus.todo,
      createdAt: _now(),
      summary: description ?? '',
    );
    _epics[id] = epic;
    return epic;
  }

  @override
  Future<ProjectIssue> createIssue({
    required String projectId,
    required String title,
    String? epicId,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  }) async {
    final IssueStatus resolvedStatus = status ?? IssueStatus.todo;
    final String? resolvedBlockedReason = resolvedStatus == IssueStatus.blocked
        ? blockedReason
        : null;
    // Same invariant `Mission.copyWith` enforces for `MissionState.blocked`
    // (`features/missions/`): a guard inside the write itself, not only in
    // `IssueFormValidation` at the caller (`design-standards.md` §3), so a
    // future caller that skips the form's own check still cannot create a
    // blocked issue with no stated cause.
    if (resolvedStatus == IssueStatus.blocked && resolvedBlockedReason == null) {
      throw ArgumentError.value(
        blockedReason,
        'blockedReason',
        'A blocked issue requires a reason.',
      );
    }
    if (epicId != null && !_epics.containsKey(epicId)) {
      throw EpicNotFoundException(epicId);
    }

    final String id = 'issue-mock-${_nextIssueSuffix++}';
    final DateTime createdAt = _now();
    final ProjectIssue issue = ProjectIssue(
      id: id,
      projectId: projectId,
      title: title,
      priority: priority ?? IssuePriority.normal,
      status: resolvedStatus,
      createdAt: createdAt,
      assignee: assigneeEmail ?? assigneeUserId ?? 'Unassigned',
      epicId: epicId,
      summary: description ?? '',
      blockedReason: resolvedBlockedReason,
      labels: labels ?? const <String>[],
      dependencies: dependencies ?? const <String>[],
      revision: 1,
      history: <IssueHistoryEvent>[
        IssueHistoryEvent(
          id: '$id-history-1',
          description: 'Issue created.',
          actor: 'You',
          occurredAt: createdAt,
        ),
      ],
    );
    _issues[id] = issue;

    if (epicId != null) {
      final Epic epic = _epics[epicId]!;
      _epics[epicId] = _epicWithIssue(epic, id);
    }

    return issue;
  }

  @override
  Future<ProjectIssue> updateIssue({
    required String issueId,
    required int revision,
    String? title,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  }) async {
    final ProjectIssue? current = _issues[issueId];
    if (current == null) {
      throw IssueNotFoundException(issueId);
    }
    // The guard belongs inside the write, not the caller
    // (`design-standards.md` §3) — this is what makes stale-write detection
    // real rather than a client-side convention every caller must remember.
    if (current.revision != revision) {
      throw StaleIssueRevisionException(
        'This issue changed since you last read it.',
      );
    }

    final IssueStatus resolvedStatus = status ?? current.status;
    final String? resolvedBlockedReason = resolvedStatus == IssueStatus.blocked
        ? (blockedReason ?? current.blockedReason)
        : null;
    if (resolvedStatus == IssueStatus.blocked && resolvedBlockedReason == null) {
      throw ArgumentError.value(
        blockedReason,
        'blockedReason',
        'A blocked issue requires a reason.',
      );
    }

    final DateTime occurredAt = _now();
    final ProjectIssue updated = ProjectIssue(
      id: current.id,
      projectId: current.projectId,
      title: title ?? current.title,
      priority: priority ?? current.priority,
      status: resolvedStatus,
      createdAt: current.createdAt,
      assignee: assigneeEmail ?? assigneeUserId ?? current.assignee,
      epicId: current.epicId,
      summary: description ?? current.summary,
      blockedReason: resolvedBlockedReason,
      labels: labels ?? current.labels,
      dependencies: dependencies ?? current.dependencies,
      revision: current.revision + 1,
      history: current.history,
    );

    final List<String> changes = describeIssueChanges(
      before: current,
      after: updated,
    );
    final ProjectIssue withHistory = changes.isEmpty
        ? updated
        : _appendHistory(updated, changes, occurredAt);

    _issues[issueId] = withHistory;
    return withHistory;
  }

  @override
  Future<ProjectIssue> linkIssueToEpic({
    required String epicId,
    required String issueId,
    required int issueRevision,
  }) async {
    final ProjectIssue? current = _issues[issueId];
    if (current == null) {
      throw IssueNotFoundException(issueId);
    }
    if (current.revision != issueRevision) {
      throw StaleIssueRevisionException(
        'This issue changed since you last read it.',
      );
    }
    final Epic? targetEpic = _epics[epicId];
    if (targetEpic == null) {
      throw EpicNotFoundException(epicId);
    }

    final String? previousEpicId = current.epicId;
    final DateTime occurredAt = _now();
    final ProjectIssue updated = ProjectIssue(
      id: current.id,
      projectId: current.projectId,
      title: current.title,
      priority: current.priority,
      status: current.status,
      createdAt: current.createdAt,
      assignee: current.assignee,
      epicId: epicId,
      summary: current.summary,
      blockedReason: current.blockedReason,
      labels: current.labels,
      dependencies: current.dependencies,
      revision: current.revision + 1,
      history: current.history,
    );
    final ProjectIssue withHistory = _appendHistory(
      updated,
      describeIssueChanges(before: current, after: updated),
      occurredAt,
    );
    _issues[issueId] = withHistory;

    if (previousEpicId != null && previousEpicId != epicId) {
      final Epic? previousEpic = _epics[previousEpicId];
      if (previousEpic != null) {
        _epics[previousEpicId] = _epicWithoutIssue(previousEpic, issueId);
      }
    }
    _epics[epicId] = _epicWithIssue(targetEpic, issueId);

    return withHistory;
  }

  static ProjectIssue _appendHistory(
    ProjectIssue issue,
    List<String> changes,
    DateTime occurredAt,
  ) {
    if (changes.isEmpty) {
      return issue;
    }
    final List<IssueHistoryEvent> history = <IssueHistoryEvent>[
      ...issue.history,
      for (int i = 0; i < changes.length; i++)
        IssueHistoryEvent(
          id: '${issue.id}-history-${issue.history.length + i + 1}',
          description: changes[i],
          actor: 'You',
          occurredAt: occurredAt,
        ),
    ];
    return ProjectIssue(
      id: issue.id,
      projectId: issue.projectId,
      title: issue.title,
      priority: issue.priority,
      status: issue.status,
      createdAt: issue.createdAt,
      assignee: issue.assignee,
      epicId: issue.epicId,
      summary: issue.summary,
      blockedReason: issue.blockedReason,
      labels: issue.labels,
      dependencies: issue.dependencies,
      revision: issue.revision,
      history: history,
    );
  }

  static Epic _epicWithIssue(Epic epic, String issueId) {
    if (epic.issueIds.contains(issueId)) {
      return epic;
    }
    return Epic(
      id: epic.id,
      projectId: epic.projectId,
      title: epic.title,
      status: epic.status,
      priority: epic.priority,
      createdAt: epic.createdAt,
      summary: epic.summary,
      blockedReason: epic.blockedReason,
      issueIds: <String>[...epic.issueIds, issueId],
    );
  }

  static Epic _epicWithoutIssue(Epic epic, String issueId) {
    if (!epic.issueIds.contains(issueId)) {
      return epic;
    }
    return Epic(
      id: epic.id,
      projectId: epic.projectId,
      title: epic.title,
      status: epic.status,
      priority: epic.priority,
      createdAt: epic.createdAt,
      summary: epic.summary,
      blockedReason: epic.blockedReason,
      issueIds: epic.issueIds.where((String id) => id != issueId).toList(growable: false),
    );
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
