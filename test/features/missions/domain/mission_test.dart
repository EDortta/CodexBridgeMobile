import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_timeline_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Mission missionWith({
    MissionState state = MissionState.active,
    String? blockedReason,
    MissionRisk risk = MissionRisk.medium,
    List<MissionTimelineEvent> timeline = const <MissionTimelineEvent>[],
  }) {
    return Mission(
      id: 'm-1',
      projectId: 'codex-bridge-mobile',
      title: 'Title',
      status: 'Status',
      stage: MissionStage.implementation,
      risk: risk,
      state: state,
      owner: 'Claude',
      progress: 0.5,
      startedAt: DateTime.utc(2026, 8, 15, 9),
      latestEvent: 'Something happened',
      blockedReason: blockedReason,
      timeline: timeline,
    );
  }

  test('every field round-trips through the constructor', () {
    final Mission mission = missionWith();

    expect(mission.projectId, 'codex-bridge-mobile');
    expect(mission.stage, MissionStage.implementation);
    expect(mission.risk, MissionRisk.medium);
    expect(mission.state, MissionState.active);
    expect(mission.owner, 'Claude');
    expect(mission.progress, 0.5);
    expect(mission.startedAt, DateTime.utc(2026, 8, 15, 9));
    expect(mission.latestEvent, 'Something happened');
  });

  test('the #28 fields default to empty when not provided', () {
    final Mission mission = missionWith();

    expect(mission.objective, '');
    expect(mission.dependencies, isEmpty);
    expect(mission.timeline, isEmpty);
    expect(mission.tests, isEmpty);
    expect(mission.files, isEmpty);
    expect(mission.artifacts, isEmpty);
    expect(mission.relatedDecisionIds, isEmpty);
  });

  group('needsIntervention', () {
    test('is true when blocked', () {
      expect(missionWith(state: MissionState.blocked).needsIntervention, isTrue);
    });

    test('is false for every other state', () {
      for (final MissionState state in MissionState.values) {
        if (state == MissionState.blocked) {
          continue;
        }
        expect(
          missionWith(state: state).needsIntervention,
          isFalse,
          reason: '$state should not need intervention',
        );
      }
    });
  });

  group('control guards', () {
    test('canPause is true only when active', () {
      expect(missionWith(state: MissionState.active).canPause, isTrue);
      expect(missionWith(state: MissionState.paused).canPause, isFalse);
      expect(missionWith(state: MissionState.blocked).canPause, isFalse);
    });

    test('canResume is true only when paused', () {
      expect(missionWith(state: MissionState.paused).canResume, isTrue);
      expect(missionWith(state: MissionState.active).canResume, isFalse);
      expect(missionWith(state: MissionState.blocked).canResume, isFalse);
    });

    test('canCancel is true for active, paused and blocked, false once finished', () {
      expect(missionWith(state: MissionState.active).canCancel, isTrue);
      expect(missionWith(state: MissionState.paused).canCancel, isTrue);
      expect(missionWith(state: MissionState.blocked).canCancel, isTrue);
      expect(missionWith(state: MissionState.completed).canCancel, isFalse);
      expect(missionWith(state: MissionState.cancelled).canCancel, isFalse);
    });
  });

  group('explanation', () {
    test('leads with the blocked reason when blocked', () {
      final List<String> reasons = missionWith(
        state: MissionState.blocked,
        blockedReason: 'Waiting on infra.',
      ).explanation;

      expect(reasons.first, 'Blocked: Waiting on infra.');
    });

    test('has no blocked-reason entry when not blocked', () {
      final List<String> reasons = missionWith().explanation;

      expect(reasons.any((String r) => r.startsWith('Blocked:')), isFalse);
    });
  });

  group('copyWith', () {
    test('moving into blocked keeps a passed blockedReason', () {
      final Mission mission = missionWith();

      final Mission blocked = mission.copyWith(
        state: MissionState.blocked,
        blockedReason: 'New blocker.',
      );

      expect(blocked.state, MissionState.blocked);
      expect(blocked.blockedReason, 'New blocker.');
    });

    test('moving away from blocked clears blockedReason automatically', () {
      final Mission mission = missionWith(
        state: MissionState.blocked,
        blockedReason: 'Old blocker.',
      );

      final Mission resumed = mission.copyWith(state: MissionState.active);

      expect(resumed.blockedReason, isNull);
    });

    test('appends to the timeline without losing earlier entries', () {
      final MissionTimelineEvent first = MissionTimelineEvent(
        id: '1',
        description: 'Mission started',
        actor: 'Claude',
        occurredAt: DateTime.utc(2026, 8, 15, 9),
      );
      final MissionTimelineEvent second = MissionTimelineEvent(
        id: '2',
        description: 'Paused by You',
        actor: 'You',
        occurredAt: DateTime.utc(2026, 8, 16),
      );
      final Mission mission = missionWith(timeline: <MissionTimelineEvent>[first]);

      final Mission updated = mission.copyWith(
        state: MissionState.paused,
        timeline: <MissionTimelineEvent>[first, second],
      );

      expect(updated.timeline, <MissionTimelineEvent>[first, second]);
    });

    test('omitting state keeps the current one', () {
      final Mission mission = missionWith(state: MissionState.paused);

      final Mission updated = mission.copyWith();

      expect(updated.state, MissionState.paused);
    });
  });
}
