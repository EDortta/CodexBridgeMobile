import 'package:codex_bridge_mobile/app/mission_repository_binding.dart';
import 'package:codex_bridge_mobile/features/missions/data/http_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/data/mock_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [resolveMissionRepository] is the decision behind [missionRepositoryBinding],
/// mirroring `resolveAuthGateway`/[authGatewayBinding]'s own test:
/// `kReleaseMode` never flips inside a single test process, so this is the
/// only way either branch gets exercised by a test at all.
void main() {
  test('a release build resolves to the real HTTP repository', () {
    final MissionRepository repository = resolveMissionRepository(
      releaseMode: true,
      resolveContext: () async => null,
    );

    expect(repository, isA<HttpMissionRepository>());
  });

  test('a non-release build resolves to the mock repository', () {
    final MissionRepository repository = resolveMissionRepository(
      releaseMode: false,
      resolveContext: () async => null,
    );

    expect(repository, isA<MockMissionRepository>());
  });
}
