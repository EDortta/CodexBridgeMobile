import 'package:codex_bridge_mobile/features/artifacts/data/mock_artifact_repository.dart';
import 'package:codex_bridge_mobile/features/artifacts/domain/artifact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every mock project id is represented, with no duplicate ids', () async {
    final List<Artifact> artifacts = await MockArtifactRepository().loadArtifacts();

    expect(
      artifacts.map((Artifact a) => a.projectId).toSet(),
      <String>{
        'codex-bridge-mobile',
        'codex-bridge',
        'codex-bridge-desktop',
        'codex-bridge-cli',
      },
    );
    expect(
      artifacts.map((Artifact a) => a.id).toSet(),
      hasLength(artifacts.length),
    );
  });
}
