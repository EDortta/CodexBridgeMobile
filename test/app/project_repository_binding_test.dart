import 'package:codex_bridge_mobile/app/project_repository_binding.dart';
import 'package:codex_bridge_mobile/features/projects/data/http_project_repository.dart';
import 'package:codex_bridge_mobile/features/projects/data/mock_project_repository.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [resolveProjectRepository] is the decision behind [projectRepositoryBinding],
/// the same shape `resolveAuthGateway` uses for `authGatewayBinding`.
/// `kReleaseMode` never flips inside a single test process, so this is the
/// only way either branch gets exercised by a test at all
/// (`design-standards.md` §1).
void main() {
  test('a release build resolves to the real HTTP repository', () {
    final ProjectRepository repository = resolveProjectRepository(
      releaseMode: true,
    );

    expect(repository, isA<HttpProjectRepository>());
  });

  test('a non-release build resolves to the mock repository', () {
    final ProjectRepository repository = resolveProjectRepository(
      releaseMode: false,
    );

    expect(repository, isA<MockProjectRepository>());
  });
}
