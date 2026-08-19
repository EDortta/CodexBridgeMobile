import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_risk.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_providers.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decisions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 19, 12);

  final Decision critical = Decision(
    id: 'critical',
    projectId: 'codex-bridge',
    title: 'Approve emergency rollback',
    requestedBy: 'Incident response',
    requestedAt: pinnedNow,
    urgency: DecisionUrgency.critical,
    risk: DecisionRisk.high,
    state: DecisionState.pending,
    deadline: pinnedNow.add(const Duration(hours: 2)),
    impactSummary: 'Production stays broken until this resolves.',
    recommendationSummary: 'Approve — reversible.',
  );
  final Decision routine = Decision(
    id: 'routine',
    projectId: 'codex-bridge-desktop',
    title: 'Approve the color palette',
    requestedBy: 'Design review',
    requestedAt: pinnedNow,
    urgency: DecisionUrgency.low,
    risk: DecisionRisk.low,
    state: DecisionState.pending,
    deadline: pinnedNow.add(const Duration(days: 30)),
    impactSummary: 'Cosmetic only.',
    recommendationSummary: 'Approve as proposed.',
  );
  final Decision alreadyApproved = Decision(
    id: 'already-approved',
    projectId: 'codex-bridge-cli',
    title: 'Approve the packaging change',
    requestedBy: 'Release planning',
    requestedAt: pinnedNow,
    urgency: DecisionUrgency.normal,
    risk: DecisionRisk.low,
    state: DecisionState.approved,
    deadline: pinnedNow.subtract(const Duration(days: 5)),
    impactSummary: 'Already resolved.',
    recommendationSummary: 'Approved.',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Decision> decisions = const <Decision>[],
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          decisionRepositoryProvider.overrideWithValue(
            _FakeDecisionRepository(decisions),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const DecisionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to showing only pending decisions', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      decisions: <Decision>[critical, routine, alreadyApproved],
    );

    expect(find.text('Approve emergency rollback'), findsOneWidget);
    expect(find.text('Approve the color palette'), findsOneWidget);
    expect(find.text('Approve the packaging change'), findsNothing);
  });

  testWidgets('a critical decision carries the Critical label; a routine one does not', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, decisions: <Decision>[critical, routine]);

    expect(find.text('Critical'), findsOneWidget);
  });

  testWidgets('each card shows the request, impact and recommendation summary', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, decisions: <Decision>[critical]);

    expect(find.text('Approve emergency rollback'), findsOneWidget);
    expect(
      find.text('Production stays broken until this resolves.'),
      findsOneWidget,
    );
    expect(find.text('Recommendation: Approve — reversible.'), findsOneWidget);
  });

  testWidgets('the urgency filter narrows to that urgency', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, decisions: <Decision>[critical, routine]);

    await tester.tap(find.byKey(const Key('decisionUrgencyFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();

    expect(find.text('Approve emergency rollback'), findsOneWidget);
    expect(find.text('Approve the color palette'), findsNothing);
  });

  testWidgets('the state filter reaches a resolved decision the default view hides', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      decisions: <Decision>[critical, routine, alreadyApproved],
    );

    await tester.tap(find.byKey(const Key('decisionStateFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved').last);
    await tester.pumpAndSettle();

    expect(find.text('Approve the packaging change'), findsOneWidget);
    expect(find.text('Approve emergency rollback'), findsNothing);
  });

  testWidgets('a no-match filter combination shows the empty state, clearable', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, decisions: <Decision>[critical, routine]);

    await tester.tap(find.byKey(const Key('decisionProjectFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('codex-bridge-desktop').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('decisionUrgencyFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();

    expect(find.text('No decisions match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Approve emergency rollback'), findsOneWidget);
    expect(find.text('Approve the color palette'), findsOneWidget);
  });

  testWidgets('no decisions at all shows the plain empty state, not the filtered one', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('No decisions yet.'), findsOneWidget);
  });
}

class _FakeDecisionRepository implements DecisionRepository {
  const _FakeDecisionRepository(this.decisions);

  final List<Decision> decisions;

  @override
  Future<List<Decision>> loadDecisions() => Future<List<Decision>>.value(decisions);
}
