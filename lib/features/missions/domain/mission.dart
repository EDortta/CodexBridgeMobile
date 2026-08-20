import 'mission_risk.dart';
import 'mission_stage.dart';
import 'mission_state.dart';
import 'mission_timeline_event.dart';

class Mission {
  const Mission({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.stage,
    required this.risk,
    required this.state,
    required this.owner,
    required this.progress,
    required this.startedAt,
    required this.latestEvent,
    this.blockedReason,
    this.objective = '',
    this.dependencies = const <String>[],
    this.timeline = const <MissionTimelineEvent>[],
    this.tests = const <String>[],
    this.files = const <String>[],
    this.artifacts = const <String>[],
    this.relatedDecisionIds = const <String>[],
  });

  final String id;
  final String projectId;
  final String title;

  /// A one-line human summary — kept for the project dashboard's (#24)
  /// "current mission" section, which shows this verbatim. [stage]/[state]
  /// are the typed model #27 adds; this field is not derived from them so
  /// existing callers see no change in wording.
  final String status;

  final MissionStage stage;
  final MissionRisk risk;
  final MissionState state;

  /// The agent responsible for this mission.
  final String owner;

  /// 0.0 (just started) to 1.0 (done).
  final double progress;

  /// When work began — the missions list's elapsed-time display
  /// (`RelativeMoment.describe`) reads against this.
  final DateTime startedAt;

  /// The most recent thing that happened on this mission.
  final String latestEvent;

  /// Why this mission is blocked — non-null only when [state] is
  /// [MissionState.blocked]. Epic #5's own acceptance criterion: "O
  /// operador entende... por que está bloqueada."
  final String? blockedReason;

  /// What this mission is trying to achieve — issue #28's detail screen
  /// shows this above the stage/timeline breakdown. Empty for a mission
  /// only ever seen through the list card (#27), the same "empty until the
  /// detail screen needs it" shape `Decision.context` uses.
  final String objective;

  /// Other missions (or external prerequisites, named in plain text) this
  /// one depends on — issue #28's "dependencies". Plain strings, not
  /// `Mission` references: a mission a project no longer tracks should not
  /// leave a dangling pointer.
  final List<String> dependencies;

  /// Every relevant transition, oldest first — issue #28's "o histórico
  /// registra toda transição relevante". Appended to by `pause`/`resume`/
  /// `cancel` (`MissionRepository`), the same append-only shape
  /// `Decision.auditTrail` uses.
  final List<MissionTimelineEvent> timeline;

  final List<String> tests;
  final List<String> files;
  final List<String> artifacts;

  /// Ids of related `Decision`s — plain strings, not `Decision` references.
  /// A feature must never import another feature
  /// (`docs/architecture/state-architecture.md`), so this stays a foreign
  /// id the detail screen can link out with (`AppRoutes.decisionDetail`)
  /// without `features/missions/` depending on `features/decisions/`.
  final List<String> relatedDecisionIds;

  /// A mission the operator needs to act on. Card+badge rendering pairs
  /// this with an icon and the [MissionState.blocked] label in text — never
  /// conveyed by color/opacity alone.
  bool get needsIntervention => state == MissionState.blocked;

  /// Whether [MissionControlAction.pause] can run from the current [state].
  bool get canPause => state == MissionState.active;

  /// Whether [MissionControlAction.resume] can run from the current
  /// [state]. Resuming a blocked mission is not offered here — a blocked
  /// mission needs its blocker resolved, not a plain resume; only a
  /// deliberately paused mission can be resumed.
  bool get canResume => state == MissionState.paused;

  /// Whether [MissionControlAction.cancel] can run from the current
  /// [state]. A mission already finished (completed or cancelled) has
  /// nothing left to cancel.
  bool get canCancel =>
      state == MissionState.active ||
      state == MissionState.paused ||
      state == MissionState.blocked;

  /// Plain-language reasons behind the current [state] — issue #28's
  /// "explain" control. Computed locally rather than fetched, since every
  /// input already lives on this mission; mirrors
  /// `LiveSessionErrorExplanation` in shape (a list of reasons) but needs no
  /// repository round trip because there is no remote log to summarize.
  List<String> get explanation {
    final List<String> reasons = <String>[];
    if (blockedReason case final String reason?) {
      reasons.add('Blocked: $reason');
    }
    reasons.add('Currently in the ${stage.label.toLowerCase()} stage.');
    reasons.add('Risk assessed as ${risk.label.toLowerCase()}.');
    reasons.add(latestEvent);
    return reasons;
  }

  /// Returns a copy with [state] (and, when moving into
  /// [MissionState.blocked], [blockedReason]) updated. Moving to any other
  /// state always clears [blockedReason] — enforcing this class's own
  /// invariant that it is non-null only while blocked, rather than trusting
  /// every call site to remember to clear it.
  Mission copyWith({
    MissionState? state,
    String? blockedReason,
    List<MissionTimelineEvent>? timeline,
  }) {
    final MissionState resolvedState = state ?? this.state;
    return Mission(
      id: id,
      projectId: projectId,
      title: title,
      status: status,
      stage: stage,
      risk: risk,
      state: resolvedState,
      owner: owner,
      progress: progress,
      startedAt: startedAt,
      latestEvent: latestEvent,
      blockedReason: resolvedState == MissionState.blocked
          ? (blockedReason ?? this.blockedReason)
          : null,
      objective: objective,
      dependencies: dependencies,
      timeline: timeline ?? this.timeline,
      tests: tests,
      files: files,
      artifacts: artifacts,
      relatedDecisionIds: relatedDecisionIds,
    );
  }
}
