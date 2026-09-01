import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_form_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #30's progressive form: step-by-step validation gating, the blocked-
/// reason field, labels/dependencies editing and the review step's diff.
/// Never taps the final "Confirm and save" here — that calls `context.go`,
/// which needs a real `GoRouter` ancestor this plain-`MaterialApp` harness
/// does not provide; the end-to-end submit path (create, edit, stale write)
/// is exercised through the real router in `test/app/issue_form_flow_test.dart`.
void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    String projectId = 'codex-bridge-mobile',
    String? issueId,
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
        child: MaterialApp(
          theme: AppTheme.light(),
          home: IssueFormScreen(projectId: projectId, issueId: issueId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continueStep(WidgetTester tester, int step) async {
    await tester.tap(find.byKey(Key('issueFormContinueStep$step')));
    await tester.pumpAndSettle();
  }

  group('create mode', () {
    testWidgets('an empty title blocks Continue from the Details step', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);

      final Finder continueButton = find.byKey(const Key('issueFormContinueStep0'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('issueFormTitleField')), 'A new issue');
      await tester.pump();

      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    });

    testWidgets('choosing Blocked reveals the reason field and blocks Continue until filled', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('issueFormTitleField')), 'A new issue');
      await tester.pump();
      await continueStep(tester, 0);

      expect(find.byKey(const Key('issueFormBlockedReasonField')), findsNothing);

      await tester.tap(find.byKey(const Key('issueFormStatusField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocked').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('issueFormBlockedReasonField')), findsOneWidget);
      final Finder continueButton = find.byKey(const Key('issueFormContinueStep1'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('issueFormBlockedReasonField')),
        'Waiting on review',
      );
      await tester.pump();

      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    });

    testWidgets('create mode offers "No epic" in the epic dropdown', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('issueFormTitleField')), 'A new issue');
      await tester.pump();
      await continueStep(tester, 0);

      await tester.tap(find.byKey(const Key('issueFormEpicField')));
      await tester.pumpAndSettle();

      expect(find.text('No epic'), findsWidgets);
    });

    testWidgets('adding and removing a label updates the chip list', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('issueFormTitleField')), 'A new issue');
      await tester.pump();
      await continueStep(tester, 0);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('issueFormLabelsEditor')),
          matching: find.byType(TextField),
        ),
        'mobile',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.widgetWithText(InputChip, 'mobile'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();

      expect(find.widgetWithText(InputChip, 'mobile'), findsNothing);
    });

    testWidgets('the review step lists the values entered, with no "Changes" section', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('issueFormTitleField')), 'A new issue');
      await tester.pump();
      await continueStep(tester, 0);
      await continueStep(tester, 1);

      // Two matches: the Details step's own title field (the Stepper keeps
      // every step's content built, not only the active one) plus the
      // review step's heading — both showing the same value is the point.
      expect(find.text('A new issue'), findsNWidgets(2));
      expect(find.text('Changes'), findsNothing);
      final Finder submitButton = find.byKey(const Key('issueFormSubmitButton'));
      expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
    });
  });

  group('edit mode', () {
    testWidgets('pre-fills every field from the existing issue', (WidgetTester tester) async {
      await pumpForm(tester, issueId: 'flaky-connection-test');

      // The Details step's title field and the review step both carry the
      // pre-filled value — see the same reasoning in the create-mode review
      // test above.
      expect(find.text('Connection test is flaky under load'), findsNWidgets(2));
    });

    testWidgets('once an epic is set, "No epic" is not offered', (WidgetTester tester) async {
      await pumpForm(tester, issueId: 'issue-epics-browser');
      await continueStep(tester, 0);

      await tester.tap(find.byKey(const Key('issueFormEpicField')));
      await tester.pumpAndSettle();

      expect(find.text('No epic'), findsNothing);
      expect(
        find.textContaining('can only be swapped for another'),
        findsOneWidget,
      );
    });

    testWidgets('changing priority is reflected in the review step\'s Changes list', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, issueId: 'flaky-connection-test');
      await continueStep(tester, 0);

      await tester.tap(find.byKey(const Key('issueFormPriorityField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Critical').last);
      await tester.pumpAndSettle();
      await continueStep(tester, 1);

      expect(find.text('Changes'), findsOneWidget);
      expect(
        find.text('• Priority changed from High to Critical.'),
        findsOneWidget,
      );
    });

    testWidgets('no edits at all shows "No changes yet." on the review step', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, issueId: 'flaky-connection-test');
      await continueStep(tester, 0);
      await continueStep(tester, 1);

      expect(find.text('No changes yet.'), findsOneWidget);
    });

    testWidgets('an unknown issue id shows the not-found message, not a blank form', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, issueId: 'does-not-exist');

      expect(find.text('This issue could not be found.'), findsOneWidget);
    });
  });
}
