import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gateway/gateway_context.dart';
import '../core/gateway/gateway_context_provider.dart';
import '../features/decisions/data/http_decision_repository.dart';
import '../features/decisions/data/mock_decision_repository.dart';
import '../features/decisions/domain/decision_repository.dart';
import '../features/decisions/presentation/decision_providers.dart';

/// The real [decisionRepositoryProvider]: [HttpDecisionRepository] against
/// the selected server and signed-in session in a release build,
/// [MockDecisionRepository] otherwise.
///
/// Composed here, not in `features/decisions/`, for the same reason
/// [authGatewayBinding] and [gatewayContextBinding] are: resolving a real
/// repository needs both the selected server and the session, and a feature
/// must not import another feature's `presentation/` layer
/// (`docs/architecture/state-architecture.md`) — `lib/app/` is the one layer
/// allowed to import both.
///
/// The mock is still the default the *feature-local* provider falls back to
/// — useful for widget tests and UI work that never installs this override
/// — but a release build now always gets this binding through `main.dart`,
/// and the branch below is the one place that decision is made, spelled out
/// rather than left implicit in which class happened to be imported. Same
/// shape as `authGatewayBinding`'s own R2 fix.
final Override decisionRepositoryBinding = decisionRepositoryProvider
    .overrideWith(
      (Ref ref) => resolveDecisionRepository(
        releaseMode: kReleaseMode,
        resolveContext: () => ref.read(gatewayContextProvider.future),
      ),
    );

/// The decision behind [decisionRepositoryBinding], pulled out so both
/// branches run under a plain unit test instead of only ever exercising the
/// one `kReleaseMode` compiles to in any given test process
/// (`design-standards.md` §1: "extract the judgement into a pure function
/// and test that").
DecisionRepository resolveDecisionRepository({
  required bool releaseMode,
  required Future<GatewayContext?> Function() resolveContext,
}) {
  if (releaseMode) {
    return HttpDecisionRepository(resolveContext);
  }
  return MockDecisionRepository();
}
