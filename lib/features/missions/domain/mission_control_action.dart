/// A command the operator can send to a [Mission] — issue #28's "pause,
/// resume, cancel" controls.
///
/// Deliberately a separate type from `LiveSessionControlAction`
/// (`features/missions/domain/live_session_repository.dart`), even though
/// both name pause/resume verbs: a [Mission] is a local, mock-backed planning
/// record (no gateway round trip, no `If-Match` revision), while a
/// [LiveSession] is a real remote process. Merging them would make one enum
/// answer for two different failure/confirmation models.
enum MissionControlAction {
  pause,
  resume,
  cancel;

  String get label => switch (this) {
    MissionControlAction.pause => 'Pause',
    MissionControlAction.resume => 'Resume',
    MissionControlAction.cancel => 'Cancel',
  };

  /// Whether sending this action needs the operator to confirm first.
  ///
  /// Pause and resume are fully reversible from this same screen — mirrors
  /// `LiveSessionControlAction.pause`/`.resume`, which also skip
  /// confirmation. Cancel is not reversible, so it always confirms; issue
  /// #28's "confirmation appropriate to impact" is met by requiring a reason
  /// for every cancel and, additionally, an explicit acknowledgement on a
  /// [MissionRisk.high] mission — the same escalation
  /// `DecisionUrgency.critical` triggers on `_ResolutionDialog`
  /// (`features/decisions/presentation/decision_detail_screen.dart`), not the
  /// generic Yes/No `runSessionControlAction` uses for session stop/restart.
  bool get requiresConfirmation => this == MissionControlAction.cancel;
}
