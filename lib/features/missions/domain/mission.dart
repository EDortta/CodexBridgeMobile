import 'mission_risk.dart';
import 'mission_stage.dart';
import 'mission_state.dart';

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

  /// A mission the operator needs to act on. Card+badge rendering pairs
  /// this with an icon and the [MissionState.blocked] label in text — never
  /// conveyed by color/opacity alone.
  bool get needsIntervention => state == MissionState.blocked;
}
