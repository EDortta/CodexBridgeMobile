import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issues_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #29's Issue view: project scope, status/priority filters, assignee and
/// labels shown per card, and a blocked issue's visual distinction.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 20);

  final ProjectIssue mobileInProgress = ProjectIssue(
    id: 'mobile-in-progress',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile issue in progress',
    priority: IssuePriority.high,
    status: IssueStatus.inProgress,
    createdAt: createdAt,
    assignee: 'Claude',
    labels: const <String>['mobile', 'planning'],
    dependencies: const <String>['Mission detail (#28)'],
  );
  final ProjectIssue mobileBlocked = ProjectIssue(
    id: 'mobile-blocked',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile issue blocked',
    priority: IssuePriority.critical,
    status: IssueStatus.blocked,
    createdAt: createdAt,
    blockedReason: 'Waiting on review.',
  );
  final ProjectIssue otherProject = ProjectIssue(
    id: 'other-project',
    projectId: 'codex-bridge',
    title: 'Other project issue',
    priority: IssuePriority.low,
    status: IssueStatus.todo,
    createdAt: createdAt,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ProjectIssue> issues = const <ProjectIssue>[],
    String projectId = 'codex-bridge-mobile',
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          issueRepositoryProvider.overrideWithValue(_FakeIssueRepository(issues: issues)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: IssuesScreen(projectId: projectId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('scopes the list to the given project', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      issues: <ProjectIssue>[mobileInProgress, mobileBlocked, otherProject],
    );

    expect(find.text('Mobile issue in progress'), findsOneWidget);
    expect(find.text('Mobile issue blocked'), findsOneWidget);
    expect(find.text('Other project issue'), findsNothing);
  });

  testWidgets('a blocked issue carries the Blocked label; a non-blocked one does not', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileInProgress, mobileBlocked]);

    // Two, both from `mobileBlocked` alone: the card's own "Blocked" banner
    // (never color-only) plus its status badge, whose label for
    // `IssueStatus.blocked` is the same word.
    expect(find.text('Blocked'), findsNWidgets(2));
  });

  testWidgets('each card shows status, priority, assignee, labels and dependency count', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileInProgress]);

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('planning'), findsOneWidget);
    expect(find.text('1 dependency(ies)'), findsOneWidget);
  });

  testWidgets('an unassigned issue shows the explicit Unassigned text', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileBlocked]);

    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets('the status filter narrows to that status', (WidgetTester tester) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileInProgress, mobileBlocked]);

    await tester.tap(find.byKey(const Key('issueStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocked').last);
    await tester.pumpAndSettle();

    expect(find.text('Mobile issue blocked'), findsOneWidget);
    expect(find.text('Mobile issue in progress'), findsNothing);
  });

  testWidgets('the priority filter narrows to that priority', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileInProgress, mobileBlocked]);

    await tester.tap(find.byKey(const Key('issuePriorityFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();

    expect(find.text('Mobile issue blocked'), findsOneWidget);
    expect(find.text('Mobile issue in progress'), findsNothing);
  });

  testWidgets('a no-match filter combination shows the empty state, clearable', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, issues: <ProjectIssue>[mobileInProgress]);

    await tester.tap(find.byKey(const Key('issueStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();

    expect(find.text('No issues match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile issue in progress'), findsOneWidget);
  });

  testWidgets('a project with no issues at all shows the plain empty state', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      issues: <ProjectIssue>[otherProject],
      projectId: 'codex-bridge-mobile',
    );

    expect(find.text('No issues for this project.'), findsOneWidget);
    expect(find.text('No issues match your filters.'), findsNothing);
  });
}

class _FakeIssueRepository implements IssueRepository {
  const _FakeIssueRepository({this.issues = const <ProjectIssue>[]});

  final List<ProjectIssue> issues;

  @override
  Future<List<ProjectIssue>> loadIssues() => Future<List<ProjectIssue>>.value(issues);

  @override
  Future<List<Epic>> loadEpics() => Future<List<Epic>>.value(const <Epic>[]);

  @override
  Future<ProjectIssue> loadIssue(String issueId) {
    return Future<ProjectIssue>.value(
      issues.firstWhere(
        (ProjectIssue i) => i.id == issueId,
        orElse: () => throw IssueNotFoundException(issueId),
      ),
    );
  }

  @override
  Future<Epic> loadEpic(String epicId) => throw EpicNotFoundException(epicId);
}
