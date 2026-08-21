import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gateway/gateway_context.dart';
import '../core/gateway/gateway_context_provider.dart';
import '../features/issues/data/http_issue_repository.dart';
import '../features/issues/data/mock_issue_repository.dart';
import '../features/issues/domain/issue_repository.dart';
import '../features/issues/presentation/issue_providers.dart';

/// The real [issueRepositoryProvider]: [HttpIssueRepository] against
/// [gatewayContextProvider] in a release build, [MockIssueRepository]
/// otherwise — the same `kReleaseMode` switch [authGatewayBinding]
/// (`lib/app/auth_gateway_binding.dart`) uses to close
/// `security-threat-model.md` finding R2, applied here so a shipped app does
/// not browse epics and issues that were never real either.
///
/// Composed here, not in `features/issues/`, for the same reason
/// [authGatewayBinding] is: `lib/app/` is the one layer allowed to import
/// both a feature's `data/` and `core/gateway/`
/// (`docs/architecture/state-architecture.md`).
final Override issueRepositoryBinding = issueRepositoryProvider.overrideWith(
  (Ref ref) => resolveIssueRepository(
    releaseMode: kReleaseMode,
    resolveContext: () => ref.read(gatewayContextProvider.future),
  ),
);

/// The decision behind [issueRepositoryBinding], pulled out so both branches
/// run under a plain unit test — the same reasoning
/// [resolveAuthGateway]'s own doc comment gives.
IssueRepository resolveIssueRepository({
  required bool releaseMode,
  required Future<GatewayContext?> Function() resolveContext,
}) {
  if (releaseMode) {
    return HttpIssueRepository(resolveContext);
  }
  return MockIssueRepository();
}
