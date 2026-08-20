import '../domain/mission.dart';
import '../domain/mission_repository.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_stage.dart';
import '../domain/mission_state.dart';
import '../domain/mission_timeline_event.dart';

/// Stands in for a real missions endpoint until one exists — same "fake
/// until the contract exists" shape `MockProjectRepository` uses, tagged
/// with the same project ids so #24's dashboard has real cross-project data
/// to filter. `codex-bridge-cli` deliberately has no mission, so the
/// dashboard's "no active mission" empty state has something real to
/// render. `id`, `projectId`, `title` and `status` on the first three
/// fixtures are exactly what #24's and #27's own tests pin — only new
/// fields were added to them.
///
/// Stateful like `MockDecisionRepository`: #28's `pause`/`resume`/`cancel`
/// mutate an in-memory map so the change sticks when the operator navigates
/// back to the missions list.
class MockMissionRepository implements MissionRepository {
  MockMissionRepository({this._clock = DateTime.timestamp})
    : _missions = <String, Mission>{
        for (final Mission mission in _seed()) mission.id: mission,
      };

  final DateTime Function() _clock;
  final Map<String, Mission> _missions;

  @override
  Future<List<Mission>> loadMissions() async => _missions.values.toList(growable: false);

  @override
  Future<Mission> loadMission(String missionId) async {
    final Mission? mission = _missions[missionId];
    if (mission == null) {
      throw MissionNotFoundException(missionId);
    }
    return mission;
  }

  @override
  Future<Mission> pause(String missionId) async {
    final Mission current = await loadMission(missionId);
    if (!current.canPause) {
      throw MissionControlNotAllowedException(
        missionId,
        'Only an active mission can be paused.',
      );
    }
    return _transition(current, MissionState.paused, 'Paused by You');
  }

  @override
  Future<Mission> resume(String missionId) async {
    final Mission current = await loadMission(missionId);
    if (!current.canResume) {
      throw MissionControlNotAllowedException(
        missionId,
        'Only a paused mission can be resumed.',
      );
    }
    return _transition(current, MissionState.active, 'Resumed by You');
  }

  @override
  Future<Mission> cancel(String missionId, {required String reason}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A cancellation requires a reason.');
    }
    final Mission current = await loadMission(missionId);
    if (!current.canCancel) {
      throw MissionControlNotAllowedException(
        missionId,
        'This mission cannot be cancelled from its current state.',
      );
    }
    return _transition(current, MissionState.cancelled, 'Cancelled by You: ${reason.trim()}');
  }

  Mission _transition(Mission current, MissionState newState, String description) {
    final MissionTimelineEvent event = MissionTimelineEvent(
      id: '${current.id}-timeline-${current.timeline.length + 1}',
      description: description,
      actor: 'You',
      occurredAt: _clock(),
    );
    final Mission updated = current.copyWith(
      state: newState,
      timeline: <MissionTimelineEvent>[...current.timeline, event],
    );
    _missions[current.id] = updated;
    return updated;
  }

  static List<Mission> _seed() => <Mission>[
    Mission(
      id: 'mobile-foundation',
      projectId: 'codex-bridge-mobile',
      title: 'Codex Bridge Mobile',
      status: 'Local foundation active',
      stage: MissionStage.documentation,
      risk: MissionRisk.low,
      state: MissionState.active,
      owner: 'Claude',
      progress: 0.85,
      startedAt: DateTime.utc(2026, 8, 3),
      latestEvent: 'Docs updated for #26',
      objective: 'Ship the mobile terminal for the Codex Bridge ecosystem.',
      dependencies: const <String>['Navigation shell (#18)', 'Auth and session lifecycle (#22)'],
      tests: const <String>['flutter analyze — clean', 'flutter test — all passing'],
      files: const <String>['lib/features/missions/', 'docs/issues/phase-4/'],
      artifacts: const <String>['docs/issues/phase-4/RESUME.md'],
      relatedDecisionIds: const <String>['shell-review'],
      timeline: <MissionTimelineEvent>[
        MissionTimelineEvent(
          id: 'mobile-foundation-timeline-1',
          description: 'Mission started',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 3),
        ),
        MissionTimelineEvent(
          id: 'mobile-foundation-timeline-2',
          description: 'Docs updated for #26',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 19),
        ),
      ],
    ),
    Mission(
      id: 'fix-development-build',
      projectId: 'codex-bridge',
      title: 'Fix the failing development build',
      status: 'Investigating',
      stage: MissionStage.implementation,
      risk: MissionRisk.high,
      state: MissionState.blocked,
      owner: 'Claude',
      progress: 0.4,
      startedAt: DateTime.utc(2026, 8, 18, 22),
      latestEvent: 'CI still failing on the integration test suite',
      blockedReason: 'Waiting on infra to restore the CI runner.',
      objective: 'Restore the development build to green.',
      dependencies: const <String>['CI runner restored by infra'],
      tests: const <String>['CI run #4821 — failing'],
      files: const <String>['.github/workflows/ci.yml'],
      relatedDecisionIds: const <String>['bridge-emergency-rollback'],
      timeline: <MissionTimelineEvent>[
        MissionTimelineEvent(
          id: 'fix-development-build-timeline-1',
          description: 'Mission started',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 18, 22),
        ),
        MissionTimelineEvent(
          id: 'fix-development-build-timeline-2',
          description: 'Blocked: waiting on infra to restore the CI runner.',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 19, 6),
        ),
      ],
    ),
    Mission(
      id: 'desktop-shell-review',
      projectId: 'codex-bridge-desktop',
      title: 'Desktop shell review',
      status: 'Awaiting review',
      stage: MissionStage.validation,
      risk: MissionRisk.medium,
      state: MissionState.paused,
      owner: 'Claude',
      progress: 0.6,
      startedAt: DateTime.utc(2026, 8, 16),
      latestEvent: 'Paused pending design sign-off',
      objective: 'Get the desktop shell reviewed and signed off.',
      dependencies: const <String>['Design sign-off'],
      files: const <String>['desktop/shell/'],
      timeline: <MissionTimelineEvent>[
        MissionTimelineEvent(
          id: 'desktop-shell-review-timeline-1',
          description: 'Mission started',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 16),
        ),
        MissionTimelineEvent(
          id: 'desktop-shell-review-timeline-2',
          description: 'Paused pending design sign-off',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 17),
        ),
      ],
    ),
    Mission(
      id: 'bridge-ci-pipeline-upgrade',
      projectId: 'codex-bridge',
      title: 'Upgrade the CI pipeline runner image',
      status: 'Completed',
      stage: MissionStage.documentation,
      risk: MissionRisk.low,
      state: MissionState.completed,
      owner: 'Claude',
      progress: 1,
      startedAt: DateTime.utc(2026, 8, 12),
      latestEvent: 'Rollout notes published',
      objective: 'Move CI onto the newer runner image.',
      tests: const <String>['CI run #4790 — passing'],
      artifacts: const <String>['Rollout notes'],
      timeline: <MissionTimelineEvent>[
        MissionTimelineEvent(
          id: 'bridge-ci-pipeline-upgrade-timeline-1',
          description: 'Mission started',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 12),
        ),
        MissionTimelineEvent(
          id: 'bridge-ci-pipeline-upgrade-timeline-2',
          description: 'Rollout notes published',
          actor: 'Claude',
          occurredAt: DateTime.utc(2026, 8, 13),
        ),
      ],
    ),
  ];
}
