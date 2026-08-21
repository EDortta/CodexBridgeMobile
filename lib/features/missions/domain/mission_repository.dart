import 'mission.dart';
import 'mission_explanation.dart';

/// Thrown when a mission id has no matching record.
class MissionNotFoundException implements Exception {
  const MissionNotFoundException(this.missionId);

  final String missionId;

  @override
  String toString() => 'No mission found with id "$missionId".';
}

/// Thrown when a control action is sent while [Mission.state] does not allow
/// it — e.g. pausing a mission that is not active. Mirrors
/// `DecisionRepository`'s validation of `reject`/`requestRevision`, which
/// also rejects the returned `Future` rather than throwing synchronously.
class MissionControlNotAllowedException implements Exception {
  const MissionControlNotAllowedException(this.missionId, this.message);

  final String missionId;
  final String message;

  @override
  String toString() => message;
}

abstract interface class MissionRepository {
  Future<List<Mission>> loadMissions();

  /// A single mission with its full detail — objective, dependencies,
  /// timeline, tests, files, artifacts and related decisions (#28). Throws
  /// [MissionNotFoundException] if [missionId] does not exist.
  Future<Mission> loadMission(String missionId);

  /// Pauses [missionId]. Throws [MissionControlNotAllowedException] unless
  /// [Mission.canPause].
  Future<Mission> pause(String missionId);

  /// Resumes [missionId]. Throws [MissionControlNotAllowedException] unless
  /// [Mission.canResume].
  Future<Mission> resume(String missionId);

  /// Cancels [missionId]. [reason] must be non-empty — issue #28's
  /// "confirmation appropriate to impact" starts with always requiring a
  /// reason for an irreversible action. Throws
  /// [MissionControlNotAllowedException] unless [Mission.canCancel].
  Future<Mission> cancel(String missionId, {required String reason});

  /// The server's own account of why [missionId] is in its current state —
  /// mirrors [Mission.explanation], but assembled remotely rather than
  /// computed from fields already on the client (see
  /// [MissionExplanation]'s own doc comment for how the two differ). Throws
  /// [MissionNotFoundException] if [missionId] does not exist.
  Future<MissionExplanation> explain(String missionId);
}

/// Thrown by a remote [MissionRepository] for a transport, authentication or
/// response-shape failure that is not one of [MissionNotFoundException] /
/// [MissionControlNotAllowedException]'s more specific meanings. Mirrors
/// `LiveSessionRepositoryException`.
class MissionRepositoryException implements Exception {
  const MissionRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
