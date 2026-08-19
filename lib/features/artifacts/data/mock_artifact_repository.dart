import '../domain/artifact.dart';
import '../domain/artifact_repository.dart';

/// Stands in for a real artifacts endpoint until one exists — CodexBridge
/// #11 ("Expose artifacts, downloads and APK metadata API") is still open.
/// Same "fake until the contract exists" shape `MockProjectRepository`
/// uses. `createdAt` is spread across recent and old values so the
/// dashboard's 7-day staleness marking has something real to demonstrate.
class MockArtifactRepository implements ArtifactRepository {
  @override
  Future<List<Artifact>> loadArtifacts() {
    return Future<List<Artifact>>.value(<Artifact>[
      Artifact(
        id: 'mobile-debug-apk',
        projectId: 'codex-bridge-mobile',
        name: 'codex-bridge-mobile-debug.apk',
        createdAt: DateTime.utc(2026, 8, 18),
      ),
      Artifact(
        id: 'bridge-server-build-log',
        projectId: 'codex-bridge',
        name: 'server-build-2026-08-05.log',
        createdAt: DateTime.utc(2026, 8, 5),
      ),
      Artifact(
        id: 'desktop-release-notes',
        projectId: 'codex-bridge-desktop',
        name: 'release-notes-draft.md',
        createdAt: DateTime.utc(2026, 8, 17),
      ),
      Artifact(
        id: 'cli-last-build',
        projectId: 'codex-bridge-cli',
        name: 'codex-bridge-cli.tar.gz',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    ]);
  }
}
