import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
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
}
