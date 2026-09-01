import 'package:codex_bridge_mobile/core/audit/audit_event.dart';
import 'package:codex_bridge_mobile/core/audit/audit_providers.dart';
import 'package:codex_bridge_mobile/core/audit/audit_trail_repository.dart';
import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/features/audit/presentation/audit_trail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #46: the trail renders read-only — every event with actor, action,
/// target, time and result, and nothing on screen that could change one.
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 26, 15);

  Future<void> pumpTrail(
    WidgetTester tester, {
    Future<void> Function(AuditTrailRepository store)? seed,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
      ],
    );
    addTearDown(container.dispose);
    if (seed != null) {
      await seed(container.read(auditTrailRepositoryProvider));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AuditTrailScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty trail says so instead of showing a blank page', (
    WidgetTester tester,
  ) async {
    await pumpTrail(tester);

    expect(
      find.textContaining('No sensitive operations have been recorded'),
      findsOneWidget,
    );
  });

  testWidgets('renders actor, action, target, time, result and failure reason', (
    WidgetTester tester,
  ) async {
    await pumpTrail(
      tester,
      seed: (AuditTrailRepository store) async {
        await store.record(
          actor: 'op-42',
          area: AuditArea.decision,
          action: 'approve',
          target: 'shell-review',
          result: AuditResult.success,
          context: <String, String>{'commentProvided': 'true'},
        );
        await store.record(
          actor: 'op-42',
          area: AuditArea.liveSession,
          action: 'stop',
          target: 's-1',
          result: AuditResult.failure,
          failureReason: 'The gateway refused the stop.',
        );
      },
    );

    expect(find.text('Decision — approve shell-review'), findsOneWidget);
    expect(find.text('Live session — stop s-1'), findsOneWidget);
    expect(find.textContaining('op-42'), findsNWidgets(2));
    expect(find.textContaining('2026-08-26 15:00 UTC'), findsNWidgets(2));
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('The gateway refused the stop.'), findsOneWidget);
    expect(find.text('commentProvided: true'), findsOneWidget);
  });

  testWidgets('newest event renders first', (WidgetTester tester) async {
    await pumpTrail(
      tester,
      seed: (AuditTrailRepository store) async {
        await store.record(
          actor: 'op-42',
          area: AuditArea.mission,
          action: 'pause',
          target: 'm-1',
          result: AuditResult.success,
        );
        await store.record(
          actor: 'op-42',
          area: AuditArea.mission,
          action: 'cancel',
          target: 'm-1',
          result: AuditResult.cancelled,
        );
      },
    );

    final Offset cancelTop = tester.getTopLeft(
      find.text('Mission — cancel m-1'),
    );
    final Offset pauseTop = tester.getTopLeft(find.text('Mission — pause m-1'));
    expect(cancelTop.dy, lessThan(pauseTop.dy));
  });

  testWidgets('an event recorded while the screen is mounted appears without renavigating', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appClockProvider.overrideWithValue(() => pinnedNow),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AuditTrailScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No sensitive operations have been recorded'),
      findsOneWidget,
    );

    // The shell keeps branches mounted, so this screen can be alive while
    // an operation elsewhere records — the new event must show up here
    // (council 2026-08-26, the second caller, round 1).
    await container.read(auditRecorderProvider).record(
      area: AuditArea.decision,
      action: 'approve',
      target: 'shell-review',
      result: AuditResult.success,
    );
    await tester.pumpAndSettle();

    expect(find.text('Decision — approve shell-review'), findsOneWidget);
  });

  testWidgets('offers no edit, delete or clear affordance', (
    WidgetTester tester,
  ) async {
    await pumpTrail(
      tester,
      seed: (AuditTrailRepository store) async {
        await store.record(
          actor: 'op-42',
          area: AuditArea.decision,
          action: 'reject',
          target: 'd-1',
          result: AuditResult.success,
        );
      },
    );

    // Immutability from normal UI (#46): the list is the whole screen — no
    // buttons of any kind, and no dismissible/swipe wrapper around a tile.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
  });
}
