import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/epic_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    String epicId, {
    IssueRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          issueRepositoryProvider.overrideWithValue(repository ?? MockIssueRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: EpicDetailScreen(epicId: epicId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows title, status, priority, project and summary', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'epic-mobile-planning');

    expect(find.text('Epic 06 — Epics, Issues e planejamento'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Project: codex-bridge-mobile'), findsOneWidget);
    expect(
      find.textContaining('Bring epics and issues into the mobile terminal'),
      findsOneWidget,
    );
  });

  testWidgets('a blocked epic states its cause in text', (WidgetTester tester) async {
    await pumpDetail(tester, 'epic-backend-contract');

    expect(
      find.textContaining('Blocked: Waiting on operator review'),
      findsOneWidget,
    );
  });

  testWidgets('lists its issues, resolved to their titles, and links to each', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'epic-mobile-planning');

    expect(find.text('Build Epics and Issues browser'), findsOneWidget);
    expect(find.text('Issue creation, editing and planning review'), findsOneWidget);
  });

  testWidgets('an epic with no issues shows the empty grouping message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'epic-desktop-shell', repository: _NoIssuesRepository());

    expect(find.text('No issues grouped under this epic yet.'), findsOneWidget);
  });

  testWidgets('an unknown epic id shows the not-found message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'does-not-exist');

    expect(find.text('This epic could not be found.'), findsOneWidget);
  });

  testWidgets('a non-not-found repository failure shows the generic message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'epic-mobile-planning', repository: _FailingIssueRepository());

    expect(find.text('Unable to load this epic.'), findsOneWidget);
  });
}

/// An epic with issue ids but a repository that reports none of them —
/// exercises `EpicDetailScreen`'s "no issues grouped" branch without
/// depending on the real mock ever shipping an epic with an empty
/// `issueIds`.
class _NoIssuesRepository implements IssueRepository {
  @override
  Future<List<ProjectIssue>> loadIssues() => Future<List<ProjectIssue>>.value(
    const <ProjectIssue>[],
  );

  @override
  Future<List<Epic>> loadEpics() => Future<List<Epic>>.value(const <Epic>[]);

  @override
  Future<ProjectIssue> loadIssue(String issueId) => throw IssueNotFoundException(issueId);

  @override
  Future<Epic> loadEpic(String epicId) => Future<Epic>.value(
    Epic(
      id: epicId,
      projectId: 'codex-bridge-desktop',
      title: 'Empty epic',
      status: IssueStatus.done,
      priority: IssuePriority.low,
      createdAt: DateTime.utc(2026, 8, 1),
    ),
  );

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

/// Throws something other than [EpicNotFoundException] from every method, so
/// `EpicDetailScreen`'s generic-fallback error branch — distinct from the
/// not-found case — has a repository that can actually reach it.
class _FailingIssueRepository implements IssueRepository {
  @override
  Future<List<ProjectIssue>> loadIssues() => throw Exception('boom');

  @override
  Future<List<Epic>> loadEpics() => throw Exception('boom');

  @override
  Future<ProjectIssue> loadIssue(String issueId) => throw Exception('boom');

  @override
  Future<Epic> loadEpic(String epicId) => throw Exception('boom');

  @override
  Future<Epic> createEpic({
    required String projectId,
    required String title,
    String? description,
    IssueStatus? status,
  }) => throw Exception('boom');

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
  }) => throw Exception('boom');

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
  }) => throw Exception('boom');

  @override
  Future<ProjectIssue> linkIssueToEpic({
    required String epicId,
    required String issueId,
    required int issueRevision,
  }) => throw Exception('boom');
}
