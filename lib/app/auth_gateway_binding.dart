import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/http_auth_gateway.dart';
import '../features/auth/data/mock_auth_gateway.dart';
import '../features/auth/domain/auth_gateway.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/server/domain/server_url.dart';
import '../features/server/presentation/server_providers.dart';

/// The real [authGatewayProvider]: [HttpAuthGateway] against the selected
/// server in a release build, [MockAuthGateway] otherwise.
///
/// Composed here, not in `features/auth/`, for the same reason
/// [gatewayContextBinding] is: resolving a real gateway needs the selected
/// server, and a feature must not import another feature's `presentation/`
/// layer (`docs/architecture/state-architecture.md`) — `lib/app/` is the one
/// layer allowed to import both.
///
/// **This closes `security-threat-model.md` finding R2**: `authGatewayProvider`
/// used to resolve to [MockAuthGateway] unconditionally, in every build
/// including release, so a shipped app authenticated nobody while looking
/// like it did. The mock is still the default the *feature-local* provider
/// falls back to — useful for widget tests and UI work that never installs
/// this override — but a release build now always gets this binding through
/// `main.dart`, and the branch below is the one place that decision is made,
/// spelled out rather than left implicit in which class happened to be
/// imported.
final Override authGatewayBinding = authGatewayProvider.overrideWith(
  (Ref ref) => resolveAuthGateway(
    releaseMode: kReleaseMode,
    now: ref.watch(sessionClockProvider),
    resolveServer: () async {
      final ServerUrl? server = await ref
          .read(serverConfigStoreProvider)
          .readSelectedServer();
      return server?.value;
    },
  ),
);

/// The decision behind [authGatewayBinding], pulled out so both branches run
/// under a plain unit test instead of only ever exercising the one
/// `kReleaseMode` compiles to in any given test process
/// (`design-standards.md` §1: "extract the judgement into a pure function and
/// test that").
AuthGateway resolveAuthGateway({
  required bool releaseMode,
  required DateTime Function() now,
  required Future<Uri?> Function() resolveServer,
}) {
  if (releaseMode) {
    return HttpAuthGateway(resolveServer, now);
  }
  return MockAuthGateway(now);
}
