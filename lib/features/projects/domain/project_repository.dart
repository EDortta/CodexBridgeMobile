import 'project_summary.dart';

/// Server and credential are per-call parameters, not constructor state —
/// the same shape `LiveSessionRepository` uses, so a repository instance
/// never goes stale across a sign-out/sign-in or a server change.
abstract interface class ProjectRepository {
  Future<List<ProjectSummary>> loadProjects({
    required Uri server,
    required String accessToken,
  });

  /// Loads one project by id.
  ///
  /// `null` means "not found, or exists in a project scope the caller
  /// cannot see" — CodexBridge answers both the same way, with a plain
  /// `404`, never `403` (`getProject` in
  /// `docs/api/codex-bridge.openapi.yaml`: "confirming that an identifier
  /// exists is what probing is for"). Callers must not treat a `null`
  /// result as an error.
  Future<ProjectSummary?> loadProject({
    required Uri server,
    required String accessToken,
    required String id,
  });
}

/// Thrown by [ProjectRepository] implementations for anything that is not
/// success and not "not found" — a transport failure, a timeout, or a
/// response this client cannot make sense of. [ProjectRepository.loadProject]
/// never throws this for a plain 404; see its own doc comment.
class ProjectRepositoryException implements Exception {
  const ProjectRepositoryException(this.message);

  final String message;
}
