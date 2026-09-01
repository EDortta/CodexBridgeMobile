import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_history_event.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockIssueRepository repository;

  setUp(() {
    repository = MockIssueRepository();
  });

  test('loadIssues returns every issue with a unique id', () async {
    final List<ProjectIssue> issues = await repository.loadIssues();

    expect(issues, isNotEmpty);
    expect(issues.map((ProjectIssue i) => i.id).toSet(), hasLength(issues.length));
  });

  test('loadEpics returns every epic with a unique id', () async {
    final List<Epic> epics = await repository.loadEpics();

    expect(epics, isNotEmpty);
    expect(epics.map((Epic e) => e.id).toSet(), hasLength(epics.length));
  });

  test('loadIssue returns the matching issue', () async {
    final ProjectIssue issue = await repository.loadIssue('fix-development-build');

    expect(issue.title, 'Development build fails on the CI runner');
    expect(issue.projectId, 'codex-bridge');
  });

  test('loadIssue throws IssueNotFoundException for an unknown id', () async {
    expect(
      () => repository.loadIssue('does-not-exist'),
      throwsA(isA<IssueNotFoundException>()),
    );
  });

  test('loadEpic returns the matching epic', () async {
    final Epic epic = await repository.loadEpic('epic-mobile-planning');

    expect(epic.projectId, 'codex-bridge-mobile');
    expect(epic.issueIds, isNotEmpty);
  });

  test('loadEpic throws EpicNotFoundException for an unknown id', () async {
    expect(
      () => repository.loadEpic('does-not-exist'),
      throwsA(isA<EpicNotFoundException>()),
    );
  });

  // #24's dashboard ("Priority issues") and its own tests
  // (`test/app/project_dashboard_screen_test.dart`) read these four issues
  // by exact id/title/priority/projectId — #29 must only add fields to them,
  // never change the four that already shipped.
  test('the four issues that predate #29 keep their id/title/priority/projectId', () async {
    final List<ProjectIssue> issues = await repository.loadIssues();
    final Map<String, ProjectIssue> byId = <String, ProjectIssue>{
      for (final ProjectIssue issue in issues) issue.id: issue,
    };

    expect(
      byId['fix-development-build']?.title,
      'Development build fails on the CI runner',
    );
    expect(byId['fix-development-build']?.priority, IssuePriority.critical);
    expect(byId['fix-development-build']?.projectId, 'codex-bridge');

    expect(byId['flaky-connection-test']?.title, 'Connection test is flaky under load');
    expect(byId['flaky-connection-test']?.priority, IssuePriority.high);
    expect(byId['flaky-connection-test']?.projectId, 'codex-bridge');

    expect(
      byId['desktop-shortcut-conflict']?.title,
      'Keyboard shortcut conflicts with the OS',
    );
    expect(byId['desktop-shortcut-conflict']?.priority, IssuePriority.normal);
    expect(byId['desktop-shortcut-conflict']?.projectId, 'codex-bridge-desktop');

    expect(
      byId['mobile-icon-polish']?.title,
      'App icon needs a higher-resolution asset',
    );
    expect(byId['mobile-icon-polish']?.priority, IssuePriority.low);
    expect(byId['mobile-icon-polish']?.projectId, 'codex-bridge-mobile');
  });

  // `project_dashboard_screen_test.dart` pins codex-bridge-cli's "No open
  // issues for this project." empty state — the mock must never grow an
  // issue or epic for that project.
  test('codex-bridge-cli carries no issue or epic', () async {
    final List<ProjectIssue> issues = await repository.loadIssues();
    final List<Epic> epics = await repository.loadEpics();

    expect(issues.where((ProjectIssue i) => i.projectId == 'codex-bridge-cli'), isEmpty);
    expect(epics.where((Epic e) => e.projectId == 'codex-bridge-cli'), isEmpty);
  });

  test('every issueId an epic names resolves to a real issue', () async {
    final List<Epic> epics = await repository.loadEpics();
    final List<ProjectIssue> issues = await repository.loadIssues();
    final Set<String> issueIds = issues.map((ProjectIssue i) => i.id).toSet();

    for (final Epic epic in epics) {
      for (final String issueId in epic.issueIds) {
        expect(
          issueIds,
          contains(issueId),
          reason: '${epic.id} names $issueId, which no seeded issue has as its id.',
        );
      }
    }
  });

  test('at least one epic and one issue are blocked, with a reason', () async {
    final List<Epic> epics = await repository.loadEpics();
    final List<ProjectIssue> issues = await repository.loadIssues();

    expect(epics.where((Epic e) => e.isBlocked), isNotEmpty);
    expect(issues.where((ProjectIssue i) => i.isBlocked), isNotEmpty);
    for (final Epic epic in epics.where((Epic e) => e.isBlocked)) {
      expect(epic.blockedReason, isNotNull);
    }
    for (final ProjectIssue issue in issues.where((ProjectIssue i) => i.isBlocked)) {
      expect(issue.blockedReason, isNotNull);
    }
  });

  // #30 — creation.
  group('createIssue', () {
    test('creates an issue with a fresh id, revision 1 and a "created" history entry', () async {
      final ProjectIssue issue = await repository.createIssue(
        projectId: 'codex-bridge-mobile',
        title: 'A brand new issue',
      );

      expect(issue.id, isNotEmpty);
      expect(issue.title, 'A brand new issue');
      expect(issue.projectId, 'codex-bridge-mobile');
      expect(issue.status, IssueStatus.todo);
      expect(issue.priority, IssuePriority.normal);
      expect(issue.assignee, 'Unassigned');
      expect(issue.revision, 1);
      expect(issue.history, hasLength(1));
      expect(issue.history.single.description, 'Issue created.');

      final ProjectIssue reloaded = await repository.loadIssue(issue.id);
      expect(reloaded.title, 'A brand new issue');
    });

    test('two created issues never collide on id', () async {
      final ProjectIssue first = await repository.createIssue(
        projectId: 'codex-bridge-mobile',
        title: 'First',
      );
      final ProjectIssue second = await repository.createIssue(
        projectId: 'codex-bridge-mobile',
        title: 'Second',
      );

      expect(first.id, isNot(second.id));
    });

    test(
      'throws ArgumentError creating a blocked issue with no blockedReason — '
      'the guard lives inside the write, not only in the form',
      () async {
        expect(
          () => repository.createIssue(
            projectId: 'codex-bridge-mobile',
            title: 'Blocked with no reason',
            status: IssueStatus.blocked,
          ),
          throwsArgumentError,
        );
      },
    );

    test('linking to an unknown epic throws EpicNotFoundException', () async {
      expect(
        () => repository.createIssue(
          projectId: 'codex-bridge-mobile',
          title: 'Orphaned',
          epicId: 'does-not-exist',
        ),
        throwsA(isA<EpicNotFoundException>()),
      );
    });

    test('links the new issue into its epic\'s issueIds', () async {
      final ProjectIssue issue = await repository.createIssue(
        projectId: 'codex-bridge-mobile',
        title: 'Linked at creation',
        epicId: 'epic-mobile-planning',
      );

      final Epic epic = await repository.loadEpic('epic-mobile-planning');
      expect(epic.issueIds, contains(issue.id));
    });
  });

  // #30 — editing, with the revision guard and the history it builds.
  group('updateIssue', () {
    test('changing a field bumps the revision and records a history entry', () async {
      final ProjectIssue before = await repository.loadIssue('flaky-connection-test');

      final ProjectIssue after = await repository.updateIssue(
        issueId: 'flaky-connection-test',
        revision: before.revision,
        priority: IssuePriority.critical,
      );

      expect(after.revision, before.revision + 1);
      expect(after.priority, IssuePriority.critical);
      expect(after.title, before.title, reason: 'unspecified fields must not change');
      expect(
        after.history.map((IssueHistoryEvent e) => e.description),
        contains('Priority changed from High to Critical.'),
      );
    });

    test('a no-op update (identical values) adds no history entry', () async {
      final ProjectIssue before = await repository.loadIssue('flaky-connection-test');

      final ProjectIssue after = await repository.updateIssue(
        issueId: 'flaky-connection-test',
        revision: before.revision,
        title: before.title,
      );

      expect(after.history.length, before.history.length);
    });

    test('throws StaleIssueRevisionException when the revision does not match', () async {
      final ProjectIssue before = await repository.loadIssue('flaky-connection-test');

      expect(
        () => repository.updateIssue(
          issueId: 'flaky-connection-test',
          revision: before.revision + 1,
          title: 'Stale write',
        ),
        throwsA(isA<StaleIssueRevisionException>()),
      );
    });

    test('moving into blocked with no reason throws — same guard as createIssue', () async {
      final ProjectIssue before = await repository.loadIssue('flaky-connection-test');

      expect(
        () => repository.updateIssue(
          issueId: 'flaky-connection-test',
          revision: before.revision,
          status: IssueStatus.blocked,
        ),
        throwsArgumentError,
      );
    });

    test('moving out of blocked clears blockedReason', () async {
      final ProjectIssue before = await repository.loadIssue('fix-development-build');
      expect(before.status, IssueStatus.blocked);
      expect(before.blockedReason, isNotNull);

      final ProjectIssue after = await repository.updateIssue(
        issueId: 'fix-development-build',
        revision: before.revision,
        status: IssueStatus.inProgress,
      );

      expect(after.blockedReason, isNull);
    });

    test('updating an unknown issue throws IssueNotFoundException', () async {
      expect(
        () => repository.updateIssue(issueId: 'does-not-exist', revision: 1, title: 'x'),
        throwsA(isA<IssueNotFoundException>()),
      );
    });
  });

  group('linkIssueToEpic', () {
    test('moves the issue and updates both epics\' issueIds', () async {
      final ProjectIssue before = await repository.loadIssue('issue-epics-browser');
      expect(before.epicId, 'epic-mobile-planning');

      final ProjectIssue after = await repository.linkIssueToEpic(
        epicId: 'epic-desktop-shell',
        issueId: 'issue-epics-browser',
        issueRevision: before.revision,
      );

      expect(after.epicId, 'epic-desktop-shell');
      final Epic oldEpic = await repository.loadEpic('epic-mobile-planning');
      final Epic newEpic = await repository.loadEpic('epic-desktop-shell');
      expect(oldEpic.issueIds, isNot(contains('issue-epics-browser')));
      expect(newEpic.issueIds, contains('issue-epics-browser'));
    });

    test('throws StaleIssueRevisionException on a stale revision', () async {
      final ProjectIssue before = await repository.loadIssue('issue-epics-browser');

      expect(
        () => repository.linkIssueToEpic(
          epicId: 'epic-desktop-shell',
          issueId: 'issue-epics-browser',
          issueRevision: before.revision + 1,
        ),
        throwsA(isA<StaleIssueRevisionException>()),
      );
    });

    test('throws EpicNotFoundException for an unknown target epic', () async {
      final ProjectIssue before = await repository.loadIssue('issue-epics-browser');

      expect(
        () => repository.linkIssueToEpic(
          epicId: 'does-not-exist',
          issueId: 'issue-epics-browser',
          issueRevision: before.revision,
        ),
        throwsA(isA<EpicNotFoundException>()),
      );
    });
  });

  group('createEpic', () {
    test('creates an epic with a fresh id', () async {
      final Epic epic = await repository.createEpic(
        projectId: 'codex-bridge-mobile',
        title: 'A brand new epic',
      );

      expect(epic.id, isNotEmpty);
      expect(epic.status, IssueStatus.todo);
      final Epic reloaded = await repository.loadEpic(epic.id);
      expect(reloaded.title, 'A brand new epic');
    });
  });
}
