import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gateway/gateway_context.dart';
import '../core/gateway/gateway_context_provider.dart';
import '../features/missions/data/http_mission_repository.dart';
import '../features/missions/data/mock_mission_repository.dart';
import '../features/missions/domain/mission_repository.dart';
import '../features/missions/presentation/mission_providers.dart';

/// The real [missionRepositoryProvider]: [HttpMissionRepository] against the
/// selected server and signed-in session in a release build,
/// [MockMissionRepository] otherwise.
///
/// Composed here, not in `features/missions/`, for the same reason
/// [authGatewayBinding] is: resolving a real repository needs both the
/// selected server (`features/server/`) and the signed-in session
/// (`features/auth/`), and a feature must not import another feature's
/// `presentation/` layer (`docs/architecture/state-architecture.md`) —
/// `lib/app/` is the one layer allowed to import across features and
/// `core/`.
///
/// The mock is still the default the *feature-local* provider falls back to
/// — useful for widget tests and UI work that never installs this override
/// — but a release build now always gets this binding through `main.dart`,
/// same as [authGatewayBinding].
final Override missionRepositoryBinding = missionRepositoryProvider.overrideWith(
  (Ref ref) => resolveMissionRepository(
    releaseMode: kReleaseMode,
    resolveContext: () async {
      final GatewayContext? context = await ref.read(gatewayContextProvider.future);
      if (context == null) {
        return null;
      }
      return (context.server, context.accessToken);
    },
  ),
);

/// The decision behind [missionRepositoryBinding], pulled out so both
/// branches run under a plain unit test instead of only ever exercising the
/// one `kReleaseMode` compiles to in any given test process
/// (`design-standards.md` §1), mirroring [resolveAuthGateway].
MissionRepository resolveMissionRepository({
  required bool releaseMode,
  required Future<(Uri, String)?> Function() resolveContext,
}) {
  if (releaseMode) {
    return HttpMissionRepository(resolveContext);
  }
  return MockMissionRepository();
}
