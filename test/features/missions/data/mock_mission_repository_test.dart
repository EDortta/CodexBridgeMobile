import 'package:codex_bridge_mobile/features/missions/data/mock_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no duplicate ids, and codex-bridge-cli has no mission', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    expect(
      missions.map((Mission m) => m.id).toSet(),
      hasLength(missions.length),
    );
    expect(
      missions.any((Mission m) => m.projectId == 'codex-bridge-cli'),
      isFalse,
      reason: "the dashboard's no-active-mission empty state needs a project with none",
    );
  });

  test('at least one mission is blocked, so the state filter has something to exclude', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    expect(missions.any((Mission m) => m.state == MissionState.blocked), isTrue);
  });

  test('a blocked mission needs intervention and carries a reason', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission blocked = missions.firstWhere(
      (Mission m) => m.state == MissionState.blocked,
    );

    expect(blocked.needsIntervention, isTrue);
    expect(blocked.blockedReason, isNotNull);
    expect(blocked.blockedReason, isNotEmpty);
  });

  test('the mobile-foundation fixture keeps the exact id/status #24 and #27 pin', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission mobile = missions.firstWhere((Mission m) => m.id == 'mobile-foundation');

    expect(mobile.status, 'Local foundation active');
  });

  test('the desktop-shell-review fixture keeps the exact title #24 pins', () async {
    final List<Mission> missions = await MockMissionRepository().loadMissions();

    final Mission desktop = missions.firstWhere(
      (Mission m) => m.id == 'desktop-shell-review',
    );

    expect(desktop.title, 'Desktop shell review');
  });

  group('loadMission', () {
    test('returns the mission with its full #28 detail', () async {
      final Mission mission = await MockMissionRepository().loadMission(
        'mobile-foundation',
      );

      expect(mission.objective, isNotEmpty);
      expect(mission.timeline, isNotEmpty);
    });

    test('throws MissionNotFoundException for an unknown id', () {
      expect(
        () => MockMissionRepository().loadMission('nope'),
        throwsA(isA<MissionNotFoundException>()),
      );
    });
  });

  group('pause', () {
    test('moves an active mission to paused and records a timeline entry', () async {
      final MockMissionRepository repository = MockMissionRepository(
        clock: () => DateTime.utc(2026, 8, 20),
      );
      final Mission before = await repository.loadMission('mobile-foundation');
      expect(before.state, MissionState.active);

      final Mission after = await repository.pause('mobile-foundation');

      expect(after.state, MissionState.paused);
      expect(after.timeline.length, before.timeline.length + 1);
      expect(after.timeline.last.description, 'Paused by You');
      expect(after.timeline.last.occurredAt, DateTime.utc(2026, 8, 20));
    });

    test('sticks — loading the mission again reflects the pause', () async {
      final MockMissionRepository repository = MockMissionRepository();
      await repository.pause('mobile-foundation');

      final Mission reloaded = await repository.loadMission('mobile-foundation');

      expect(reloaded.state, MissionState.paused);
    });

    test('throws MissionControlNotAllowedException on a mission that is not active', () {
      final MockMissionRepository repository = MockMissionRepository();

      expect(
        () => repository.pause('desktop-shell-review'),
        throwsA(isA<MissionControlNotAllowedException>()),
      );
    });

    test(
      'two calls issued back-to-back do not race — the second sees the '
      'already-paused state instead of silently overwriting the first',
      () async {
        final MockMissionRepository repository = MockMissionRepository(
          clock: () => DateTime.utc(2026, 8, 20),
        );

        // Deliberately not awaited between the two calls: this is the
        // "double tap before the button hides" / "two callers racing the
        // same mission" shape — both requests are already in flight before
        // either has a chance to observe the other's result. `pause()` has
        // no internal `await`, so both run to completion synchronously,
        // back to back — which is exactly why the second call's outcome is
        // captured via `.then(onError:)` in the same synchronous step it is
        // created in, rather than awaited later: an async function that
        // rejects before its first `await` reports as an unhandled error at
        // the call site if nothing has claimed it yet by the time this test
        // body's own synchronous stretch ends.
        final Future<Mission> first = repository.pause('mobile-foundation');
        final Future<Object> secondOutcome = repository
            .pause('mobile-foundation')
            .then<Object>((Mission mission) => mission, onError: (Object error) => error);

        final Mission firstResult = await first;
        final Object secondResult = await secondOutcome;

        expect(secondResult, isA<MissionControlNotAllowedException>());
        final Mission reloaded = await repository.loadMission('mobile-foundation');
        expect(reloaded.timeline.length, firstResult.timeline.length);
        expect(reloaded.timeline.last.description, 'Paused by You');
      },
    );
  });

  group('resume', () {
    test('moves a paused mission back to active and records a timeline entry', () async {
      final MockMissionRepository repository = MockMissionRepository();

      final Mission after = await repository.resume('desktop-shell-review');

      expect(after.state, MissionState.active);
      expect(after.timeline.last.description, 'Resumed by You');
    });

    test('throws MissionControlNotAllowedException on a mission that is not paused', () {
      final MockMissionRepository repository = MockMissionRepository();

      expect(
        () => repository.resume('mobile-foundation'),
        throwsA(isA<MissionControlNotAllowedException>()),
      );
    });
  });

  group('cancel', () {
    test('cancels an active mission, records the reason on the timeline', () async {
      final MockMissionRepository repository = MockMissionRepository();

      final Mission after = await repository.cancel(
        'mobile-foundation',
        reason: 'No longer needed.',
      );

      expect(after.state, MissionState.cancelled);
      expect(after.timeline.last.description, contains('No longer needed.'));
    });

    test('cancels a blocked mission too', () async {
      final MockMissionRepository repository = MockMissionRepository();

      final Mission after = await repository.cancel(
        'fix-development-build',
        reason: 'Scrapping this approach.',
      );

      expect(after.state, MissionState.cancelled);
    });

    test('rejects an empty reason', () {
      final MockMissionRepository repository = MockMissionRepository();

      expect(
        () => repository.cancel('mobile-foundation', reason: '  '),
        throwsArgumentError,
      );
    });

    test('throws MissionControlNotAllowedException on an already-finished mission', () {
      final MockMissionRepository repository = MockMissionRepository();

      expect(
        () => repository.cancel('bridge-ci-pipeline-upgrade', reason: 'Too late.'),
        throwsA(isA<MissionControlNotAllowedException>()),
      );
    });
  });
}
