import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/projects/data/http_project_repository.dart';
import '../features/projects/data/mock_project_repository.dart';
import '../features/projects/domain/project_repository.dart';
import '../features/projects/presentation/project_providers.dart';

/// The real [projectRepositoryProvider]: [HttpProjectRepository] against the
/// real Codex Bridge gateway in a release build, [MockProjectRepository]
/// otherwise.
///
/// Composed here, in `lib/app/`, exactly like `auth_gateway_binding.dart`
/// composes [projectRepositoryProvider]'s counterpart for auth — a feature
/// must not decide for itself whether it is talking to a real server
/// (`docs/architecture/state-architecture.md`), and unlike
/// `gatewayContextBinding` this decision needs nothing from another
/// feature, so it lives next to the provider it overrides rather than
/// forcing an import of `auth`/`server` into `features/projects/`.
///
/// The mock is still the default `projectRepositoryProvider` resolves to
/// when this override is absent — every existing widget test, and any UI
/// work that never installs `main.dart`'s overrides.
final Override projectRepositoryBinding = projectRepositoryProvider
    .overrideWith((Ref ref) => resolveProjectRepository(releaseMode: kReleaseMode));

/// The decision behind [projectRepositoryBinding], pulled out so both
/// branches run under a plain unit test instead of only ever exercising the
/// one `kReleaseMode` compiles to in a given test process
/// (`design-standards.md` §1, the same reason `resolveAuthGateway` exists).
ProjectRepository resolveProjectRepository({required bool releaseMode}) {
  if (releaseMode) {
    return const HttpProjectRepository();
  }
  return MockProjectRepository();
}
