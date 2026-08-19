import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/features/decisions/data/mock_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_detail_screen.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #26: detail context, discussion, resolution history, and the
/// approve/reject/request-revision/discuss actions — including the
/// stronger, decision-specific confirmation critical decisions require
/// (never the plain Yes/No dialog `runSessionControlAction` uses).
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 19, 12);

  Future<void> pumpDetail(WidgetTester tester, String decisionId) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          decisionRepositoryProvider.overrideWithValue(
            MockDecisionRepository(clock: () => pinnedNow),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DecisionDetailScreen(decisionId: decisionId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows context, impact, risks, evidence and affected entities', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'bridge-emergency-rollback');

    expect(
      find.textContaining('The development build has failed'),
      findsOneWidget,
    );
    expect(
      find.text('Production build stays broken until this is resolved.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('High risk if delayed further'),
      findsOneWidget,
    );
    expect(find.textContaining('CI run #4821'), findsOneWidget);
    expect(find.textContaining('Codex Bridge — production build'), findsOneWidget);
  });

  testWidgets('a pending decision with no history shows the empty discussion and audit copy', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'shell-review');

    expect(find.text('No comments yet.'), findsOneWidget);
    expect(find.text('No resolution actions yet.'), findsOneWidget);
  });

  testWidgets('an already-resolved decision hides the resolution actions but keeps Discuss', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'cli-already-approved');

    expect(find.text('This decision was already approved.'), findsOneWidget);
    expect(find.byKey(const Key('decisionApproveButton')), findsNothing);
    expect(find.byKey(const Key('decisionRejectButton')), findsNothing);
    expect(find.byKey(const Key('decisionRequestRevisionButton')), findsNothing);
    expect(find.byKey(const Key('decisionDiscussButton')), findsOneWidget);
  });

  testWidgets('approving a non-critical decision resolves it, no confirmation checkbox shown', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'shell-review');

    await tester.tap(find.byKey(const Key('decisionApproveButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('decisionCriticalAcknowledgeCheckbox')),
      findsNothing,
    );
    // Approval's comment is optional — submit is enabled immediately.
    await tester.tap(find.byKey(const Key('decisionResolutionSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('This decision was already approved.'), findsOneWidget);
    expect(find.textContaining('Approved by You'), findsOneWidget);
  });

  testWidgets('rejecting requires a non-empty justification before submit enables', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'shell-review');

    await tester.tap(find.byKey(const Key('decisionRejectButton')));
    await tester.pumpAndSettle();

    final Finder submit = find.byKey(const Key('decisionResolutionSubmitButton'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('decisionResolutionCommentField')),
      'Not ready — missing test coverage.',
    );
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('This decision was already rejected.'), findsOneWidget);
    expect(find.text('Not ready — missing test coverage.'), findsOneWidget);
  });

  testWidgets('a critical decision requires the acknowledgement checkbox before submit enables', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'bridge-emergency-rollback');

    await tester.tap(find.byKey(const Key('decisionApproveButton')));
    await tester.pumpAndSettle();

    final Finder submit = find.byKey(const Key('decisionResolutionSubmitButton'));
    final Finder checkbox = find.byKey(
      const Key('decisionCriticalAcknowledgeCheckbox'),
    );
    expect(checkbox, findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('discussing appends a comment without changing the state', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'shell-review');

    await tester.tap(find.byKey(const Key('decisionDiscussButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('decisionResolutionCommentField')),
      'Can we get a second reviewer?',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decisionResolutionSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Can we get a second reviewer?'), findsOneWidget);
    // Discuss never resolves the decision — the action buttons stay.
    expect(find.byKey(const Key('decisionApproveButton')), findsOneWidget);
  });

  testWidgets('discuss requires a non-empty comment before submit enables', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'shell-review');

    await tester.tap(find.byKey(const Key('decisionDiscussButton')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('decisionResolutionSubmitButton')))
          .onPressed,
      isNull,
    );
  });
}
