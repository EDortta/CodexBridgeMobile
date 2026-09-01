import 'package:codex_bridge_mobile/core/audit/audit_event.dart';
import 'package:codex_bridge_mobile/core/audit/audit_providers.dart';
import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:codex_bridge_mobile/features/missions/data/mock_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_explanation.dart';
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

  // #46: every mission control outcome — success, failure, backed out —
  // lands on the cross-cutting audit trail.
  group('audit trail', () {
    Future<ProviderContainer> pumpAudited(
      WidgetTester tester,
      String missionId, {
      MissionRepository? repository,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => pinnedNow),
          auditActorProvider.overrideWithValue('op-42'),
          missionRepositoryProvider.overrideWithValue(
            repository ?? MockMissionRepository(clock: () => pinnedNow),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MissionDetailScreen(missionId: missionId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('pausing records success', (WidgetTester tester) async {
      final ProviderContainer container = await pumpAudited(
        tester,
        'mobile-foundation',
      );

      await tester.tap(find.byKey(const Key('missionPauseButton')));
      await tester.pumpAndSettle();

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.area, AuditArea.mission);
      expect(event.action, 'pause');
      expect(event.target, 'mobile-foundation');
      expect(event.actor, 'op-42');
      expect(event.result, AuditResult.success);
    });

    testWidgets('a confirmed cancel records success with the reason flag only', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpAudited(
        tester,
        'desktop-shell-review',
      );

      await tester.tap(find.byKey(const Key('missionCancelButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('missionCancelReasonField')),
        'Design sign-off will not happen.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('missionCancelSubmitButton')));
      await tester.pumpAndSettle();

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.action, 'cancel');
      expect(event.result, AuditResult.success);
      // The reason's text lands on the mission's own timeline, never here.
      expect(event.context, <String, String>{'reasonProvided': 'true'});
    });

    testWidgets('backing out of the cancel dialog records cancelled', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpAudited(
        tester,
        'desktop-shell-review',
      );

      await tester.tap(find.byKey(const Key('missionCancelButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep mission'));
      await tester.pumpAndSettle();

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.action, 'cancel');
      expect(event.result, AuditResult.cancelled);
    });

    testWidgets('a repository failure records failure with the reason', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpAudited(
        tester,
        'mobile-foundation',
        repository: _PauseRefusedMissionRepository(
          MockMissionRepository(clock: () => pinnedNow),
        ),
      );

      await tester.tap(find.byKey(const Key('missionPauseButton')));
      await tester.pumpAndSettle();

      final List<AuditEvent> events = await container
          .read(auditTrailRepositoryProvider)
          .loadEvents();
      final AuditEvent event = events.single;
      expect(event.action, 'pause');
      expect(event.result, AuditResult.failure);
      expect(event.failureReason, contains('refused'));
    });
  });
}

/// Refuses `pause` the way a gateway would; everything else passes through
/// to the wrapped repository, so the screen still loads its mission.
class _PauseRefusedMissionRepository implements MissionRepository {
  _PauseRefusedMissionRepository(this._inner);

  final MissionRepository _inner;

  @override
  Future<List<Mission>> loadMissions() => _inner.loadMissions();

  @override
  Future<Mission> loadMission(String missionId) => _inner.loadMission(missionId);

  @override
  Future<Mission> pause(String missionId) async {
    throw const MissionRepositoryException('The gateway refused the pause.');
  }

  @override
  Future<Mission> resume(String missionId) => _inner.resume(missionId);

  @override
  Future<Mission> cancel(String missionId, {required String reason}) =>
      _inner.cancel(missionId, reason: reason);

  @override
  Future<MissionExplanation> explain(String missionId) =>
      _inner.explain(missionId);
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

  @override
  Future<MissionExplanation> explain(String missionId) => throw Exception('boom');
}
