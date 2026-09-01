import 'package:codex_bridge_mobile/app/app.dart';
import 'package:codex_bridge_mobile/app/app_router.dart';
import 'package:codex_bridge_mobile/core/navigation/app_destinations.dart';
import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #30's create/edit form exercised end to end through the real router, the
/// same shape `app_router_test.dart` and `project_dashboard_screen_test.dart`
/// use — `IssueFormScreen`'s submit path calls `context.go`, which needs a
/// real `GoRouter` ancestor (`test/features/issues/presentation/
/// issue_form_screen_test.dart` covers the form's own step/validation logic
/// with a plain `MaterialApp` and never taps submit).
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String initialLocation, {
    MockIssueRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          issueRepositoryProvider.overrideWithValue(repository ?? MockIssueRepository()),
        ],
        child: CodexBridgeMobileApp(
          router: createAppRouter(initialLocation: initialLocation),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continueStep(WidgetTester tester, int step) async {
    await tester.tap(find.byKey(Key('issueFormContinueStep$step')));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping New issue on the Issues screen opens the create form, scoped to it', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'issues': 'codex-bridge-mobile'},
      ).toString(),
    );

    await tester.tap(find.byKey(const Key('newIssueButton')));
    await tester.pumpAndSettle();

    expect(find.text('New issue'), findsWidgets);
  });

  testWidgets('creating an issue lands on its own detail screen with the review\'s values', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'newIssue': 'codex-bridge-mobile'},
      ).toString(),
    );

    await tester.enterText(
      find.byKey(const Key('issueFormTitleField')),
      'Investigate flaky boot on rooted devices',
    );
    await tester.pump();
    await continueStep(tester, 0);
    await continueStep(tester, 1);
    await tester.tap(find.byKey(const Key('issueFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byType(IssueDetailScreen), findsOneWidget);
    expect(find.text('Investigate flaky boot on rooted devices'), findsOneWidget);
    expect(find.text('Issue created.'), findsOneWidget);
  });

  testWidgets('editing an issue from its detail screen updates it and records history', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'issue': 'flaky-connection-test'},
      ).toString(),
    );

    await tester.tap(find.byKey(const Key('editIssueButton')));
    await tester.pumpAndSettle();

    await continueStep(tester, 0);
    await tester.tap(find.byKey(const Key('issueFormPriorityField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();
    await continueStep(tester, 1);
    await tester.tap(find.byKey(const Key('issueFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byType(IssueDetailScreen), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);
    expect(
      find.text('Priority changed from High to Critical.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a concurrent edit surfaces the stale-write dialog instead of silently overwriting it',
    (WidgetTester tester) async {
      final MockIssueRepository repository = MockIssueRepository();
      await pumpAt(
        tester,
        Uri(
          path: AppDestination.projects.detailPath,
          queryParameters: <String, String>{'issue': 'flaky-connection-test'},
        ).toString(),
        repository: repository,
      );

      await tester.tap(find.byKey(const Key('editIssueButton')));
      await tester.pumpAndSettle();

      // Someone else updates the same issue while this form is open —
      // bumping its revision behind this screen's back, the same way a
      // second operator or the gateway itself would.
      final ProjectIssue current = await repository.loadIssue('flaky-connection-test');
      await repository.updateIssue(
        issueId: 'flaky-connection-test',
        revision: current.revision,
        title: 'Retitled from elsewhere',
      );

      await continueStep(tester, 0);
      await continueStep(tester, 1);
      await tester.tap(find.byKey(const Key('issueFormSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('This issue changed'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(IssueDetailScreen), findsOneWidget);
      expect(find.text('Retitled from elsewhere'), findsOneWidget);
    },
  );
}
