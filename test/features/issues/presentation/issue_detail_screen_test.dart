import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    String issueId, {
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
          home: IssueDetailScreen(issueId: issueId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows title, status, priority, assignee, project and summary', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'issue-epics-browser');

    expect(find.text('Build Epics and Issues browser'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Project: codex-bridge-mobile'), findsOneWidget);
    expect(find.textContaining('Project-scoped lists'), findsOneWidget);
  });

  testWidgets('shows every label as a chip', (WidgetTester tester) async {
    await pumpDetail(tester, 'issue-epics-browser');

    expect(find.widgetWithText(Chip, 'mobile'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'planning'), findsOneWidget);
  });

  testWidgets('shows its dependencies as a bulleted list', (WidgetTester tester) async {
    await pumpDetail(tester, 'issue-epics-browser');

    expect(find.text('Dependencies'), findsOneWidget);
    expect(
      find.text('• Mission detail, timeline and controls (#28)'),
      findsOneWidget,
    );
  });

  testWidgets('a blocked issue states its cause in text', (WidgetTester tester) async {
    await pumpDetail(tester, 'fix-development-build');

    expect(
      find.textContaining('Blocked: Waiting on operator review'),
      findsOneWidget,
    );
  });

  testWidgets('an issue with an epic links to that epic by its resolved title', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'issue-epics-browser');

    expect(find.text('Epic'), findsOneWidget);
    expect(find.text('Epic 06 — Epics, Issues e planejamento'), findsOneWidget);
  });

  testWidgets('an issue with no epic shows no epic card', (WidgetTester tester) async {
    await pumpDetail(tester, 'mobile-icon-polish');

    expect(find.text('Epic'), findsNothing);
  });

  testWidgets('an unknown issue id shows the not-found message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'does-not-exist');

    expect(find.text('This issue could not be found.'), findsOneWidget);
  });

  testWidgets('a non-not-found repository failure shows the generic message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(
      tester,
      'issue-epics-browser',
      repository: _FailingIssueRepository(),
    );

    expect(find.text('Unable to load this issue.'), findsOneWidget);
  });
}

/// Throws something other than [IssueNotFoundException] from every method,
/// so `IssueDetailScreen`'s generic-fallback error branch — distinct from
/// the not-found case — has a repository that can actually reach it.
class _FailingIssueRepository implements IssueRepository {
  @override
  Future<List<ProjectIssue>> loadIssues() => throw Exception('boom');

  @override
  Future<List<Epic>> loadEpics() => throw Exception('boom');

  @override
  Future<ProjectIssue> loadIssue(String issueId) => throw Exception('boom');

  @override
  Future<Epic> loadEpic(String epicId) => throw Exception('boom');
}
