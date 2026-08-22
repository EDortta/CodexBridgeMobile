import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/epics_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #29's Epic view: project scope, status/priority filters, and a blocked
/// epic's visual distinction (never color alone).
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 20);

  final Epic mobileHighTodo = Epic(
    id: 'mobile-high-todo',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile epic in progress',
    status: IssueStatus.inProgress,
    priority: IssuePriority.high,
    createdAt: createdAt,
    issueIds: const <String>['issue-a', 'issue-b'],
  );
  final Epic mobileBlocked = Epic(
    id: 'mobile-blocked',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile epic blocked',
    status: IssueStatus.blocked,
    priority: IssuePriority.critical,
    createdAt: createdAt,
    blockedReason: 'Waiting on review.',
  );
  final Epic otherProject = Epic(
    id: 'other-project',
    projectId: 'codex-bridge',
    title: 'Other project epic',
    status: IssueStatus.todo,
    priority: IssuePriority.low,
    createdAt: createdAt,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Epic> epics = const <Epic>[],
    String projectId = 'codex-bridge-mobile',
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          issueRepositoryProvider.overrideWithValue(_FakeIssueRepository(epics: epics)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: EpicsScreen(projectId: projectId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('scopes the list to the given project', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      epics: <Epic>[mobileHighTodo, mobileBlocked, otherProject],
    );

    expect(find.text('Mobile epic in progress'), findsOneWidget);
    expect(find.text('Mobile epic blocked'), findsOneWidget);
    expect(find.text('Other project epic'), findsNothing);
  });

  testWidgets('a blocked epic carries the Blocked label; a non-blocked one does not', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, epics: <Epic>[mobileHighTodo, mobileBlocked]);

    // Two, both from `mobileBlocked` alone: the card's own "Blocked" banner
    // (never color-only) plus its status badge, whose label for
    // `IssueStatus.blocked` is the same word — `mobileHighTodo`'s card
    // contributes neither.
    expect(find.text('Blocked'), findsNWidgets(2));
  });

  testWidgets('each card shows status, priority and its issue count', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, epics: <Epic>[mobileHighTodo]);

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('2 issue(s)'), findsOneWidget);
  });

  testWidgets('the status filter narrows to that status', (WidgetTester tester) async {
    await pumpScreen(tester, epics: <Epic>[mobileHighTodo, mobileBlocked]);

    await tester.tap(find.byKey(const Key('epicStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocked').last);
    await tester.pumpAndSettle();

    expect(find.text('Mobile epic blocked'), findsOneWidget);
    expect(find.text('Mobile epic in progress'), findsNothing);
  });

  testWidgets('the priority filter narrows to that priority', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, epics: <Epic>[mobileHighTodo, mobileBlocked]);

    await tester.tap(find.byKey(const Key('epicPriorityFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();

    expect(find.text('Mobile epic blocked'), findsOneWidget);
    expect(find.text('Mobile epic in progress'), findsNothing);
  });

  testWidgets('a no-match filter combination shows the empty state, clearable', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, epics: <Epic>[mobileHighTodo]);

    await tester.tap(find.byKey(const Key('epicStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();

    expect(find.text('No epics match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile epic in progress'), findsOneWidget);
  });

  testWidgets('a project with no epics at all shows the plain empty state', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, epics: <Epic>[otherProject], projectId: 'codex-bridge-mobile');

    expect(find.text('No epics for this project.'), findsOneWidget);
    expect(find.text('No epics match your filters.'), findsNothing);
  });
}

class _FakeIssueRepository implements IssueRepository {
  const _FakeIssueRepository({this.epics = const <Epic>[]});

  final List<Epic> epics;

  @override
  Future<List<ProjectIssue>> loadIssues() => Future<List<ProjectIssue>>.value(
    const <ProjectIssue>[],
  );

  @override
  Future<List<Epic>> loadEpics() =>
      Future<List<Epic>>.value(epics);

  @override
  Future<ProjectIssue> loadIssue(String issueId) => throw IssueNotFoundException(issueId);

  @override
  Future<Epic> loadEpic(String epicId) {
    return Future<Epic>.value(
      epics.firstWhere(
        (Epic e) => e.id == epicId,
        orElse: () => throw EpicNotFoundException(epicId),
      ),
    );
  }

  @override
  Future<Epic> createEpic({
    required String projectId,
    required String title,
    String? description,
    IssueStatus? status,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<ProjectIssue> linkIssueToEpic({
    required String epicId,
    required String issueId,
    required int issueRevision,
  }) => throw UnimplementedError();
}
