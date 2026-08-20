import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/features/missions/data/mock_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_detail_screen.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #28: detail context, dependencies, tests/files/artifacts, related
/// decisions, timeline, and the pause/resume/cancel/explain actions —
/// including the stronger, mission-specific confirmation a high-risk cancel
/// requires (never the plain Yes/No dialog `runSessionControlAction` uses).
void main() {
  final DateTime pinnedNow = DateTime.utc(2026, 8, 20, 12);

  Future<void> pumpDetail(WidgetTester tester, String missionId) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          missionRepositoryProvider.overrideWithValue(
            MockMissionRepository(clock: () => pinnedNow),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MissionDetailScreen(missionId: missionId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows objective, dependencies, tests, files and artifacts', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'mobile-foundation');

    expect(find.textContaining('Ship the mobile terminal'), findsOneWidget);
    expect(find.textContaining('Navigation shell (#18)'), findsOneWidget);
    expect(find.textContaining('flutter analyze — clean'), findsOneWidget);
    expect(find.textContaining('lib/features/missions/'), findsOneWidget);
    expect(find.textContaining('docs/issues/phase-4/RESUME.md'), findsOneWidget);
  });

  testWidgets('a blocked mission states its cause in text, not only the badge', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'fix-development-build');

    expect(
      find.text('Blocked: Waiting on infra to restore the CI runner.'),
      findsOneWidget,
    );
  });

  testWidgets('shows related decisions as links', (WidgetTester tester) async {
    await pumpDetail(tester, 'mobile-foundation');

    expect(find.text('Related decisions'), findsOneWidget);
    expect(find.text('shell-review'), findsOneWidget);
  });

  testWidgets('an active mission offers Pause and Cancel, not Resume', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'mobile-foundation');

    expect(find.byKey(const Key('missionPauseButton')), findsOneWidget);
    expect(find.byKey(const Key('missionResumeButton')), findsNothing);
    expect(find.byKey(const Key('missionCancelButton')), findsOneWidget);
  });

  testWidgets('a paused mission offers Resume, not Pause', (WidgetTester tester) async {
    await pumpDetail(tester, 'desktop-shell-review');

    expect(find.byKey(const Key('missionResumeButton')), findsOneWidget);
    expect(find.byKey(const Key('missionPauseButton')), findsNothing);
  });

  testWidgets('a completed mission offers no pause/resume/cancel controls', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'bridge-ci-pipeline-upgrade');

    expect(find.byKey(const Key('missionPauseButton')), findsNothing);
    expect(find.byKey(const Key('missionResumeButton')), findsNothing);
    expect(find.byKey(const Key('missionCancelButton')), findsNothing);
    expect(find.textContaining('no further controls apply'), findsOneWidget);
  });

  testWidgets('pausing appends a timeline entry and flips the state', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'mobile-foundation');

    await tester.tap(find.byKey(const Key('missionPauseButton')));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsWidgets);
    expect(find.textContaining('Paused by You'), findsOneWidget);
  });

  testWidgets(
    'cancelling a low/medium-risk mission needs only a reason, no acknowledgement checkbox',
    (WidgetTester tester) async {
      await pumpDetail(tester, 'desktop-shell-review');

      await tester.tap(find.byKey(const Key('missionCancelButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('missionCancelAcknowledgeCheckbox')),
        findsNothing,
      );
      final Finder submit = find.byKey(const Key('missionCancelSubmitButton'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('missionCancelReasonField')),
        'Design sign-off will not happen.',
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsWidgets);
    },
  );

  testWidgets(
    'cancelling a high-risk mission requires the acknowledgement checkbox before submit enables',
    (WidgetTester tester) async {
      await pumpDetail(tester, 'fix-development-build');

      await tester.tap(find.byKey(const Key('missionCancelButton')));
      await tester.pumpAndSettle();

      final Finder submit = find.byKey(const Key('missionCancelSubmitButton'));
      final Finder checkbox = find.byKey(
        const Key('missionCancelAcknowledgeCheckbox'),
      );
      expect(checkbox, findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('missionCancelReasonField')),
        'Scrapping this approach.',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    },
  );

  testWidgets('Explain opens a dialog with the mission\'s reasons, including the blocker', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'fix-development-build');

    await tester.tap(find.byKey(const Key('missionExplainButton')));
    await tester.pumpAndSettle();

    // The summary card's own blocked banner already shows this text, so the
    // dialog contributes a second match, not the only one.
    expect(
      find.textContaining('Blocked: Waiting on infra to restore the CI runner.'),
      findsWidgets,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Why this mission is where it is'), findsNothing);
  });

  testWidgets('the timeline card lists every seeded transition', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'mobile-foundation');

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Mission started'), findsOneWidget);
    expect(find.text('Docs updated for #26'), findsWidgets);
    expect(find.text('No transitions recorded yet.'), findsNothing);
  });

  testWidgets('an unknown mission id shows the not-found message', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, 'does-not-exist');

    expect(find.text('This mission could not be found.'), findsOneWidget);
  });

  testWidgets('a non-not-found repository failure shows the generic message', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          missionRepositoryProvider.overrideWithValue(_FailingMissionRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MissionDetailScreen(missionId: 'mobile-foundation'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load this mission.'), findsOneWidget);
  });
}

/// Throws something other than [MissionNotFoundException] from every method,
/// so `MissionDetailScreen`'s generic-fallback error branch — the `_` case
/// in `_errorMessage`, distinct from the not-found case — has a repository
/// that can actually reach it.
class _FailingMissionRepository implements MissionRepository {
  @override
  Future<List<Mission>> loadMissions() => throw Exception('boom');

  @override
  Future<Mission> loadMission(String missionId) => throw Exception('boom');

  @override
  Future<Mission> pause(String missionId) => throw Exception('boom');

  @override
  Future<Mission> resume(String missionId) => throw Exception('boom');

  @override
  Future<Mission> cancel(String missionId, {required String reason}) =>
      throw Exception('boom');
}
