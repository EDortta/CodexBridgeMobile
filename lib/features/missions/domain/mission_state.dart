/// A [Mission]'s operational status — distinct from [MissionStage], which
/// names *what phase of work* is underway. `blocked` is what
/// [Mission.needsIntervention] keys off; `active`/`paused`/`completed`/
/// `cancelled` are the pause/resume/cancel verbs Epic #5's scope names.
enum MissionState {
  active,
  blocked,
  paused,
  completed,
  cancelled;

  String get label => switch (this) {
    MissionState.active => 'Active',
    MissionState.blocked => 'Blocked',
    MissionState.paused => 'Paused',
    MissionState.completed => 'Completed',
    MissionState.cancelled => 'Cancelled',
  };
}
