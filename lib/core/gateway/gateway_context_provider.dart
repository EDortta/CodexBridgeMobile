import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_context.dart';

/// Where a feature reads the server and credential it needs to call the
/// gateway, without depending on `auth` or `server` directly.
///
/// Resolves to "not configured" by default: `core/` must not import a feature
/// (`docs/architecture/state-architecture.md`), so the real resolution — the
/// selected server plus the signed-in session — is wired in as an override by
/// `lib/app/`, the one layer allowed to import every feature's presentation
/// layer. A feature that needs it just watches this provider; a test that
/// needs a fixed answer overrides it directly instead of seeding storage two
/// features away.
final FutureProvider<GatewayContext?> gatewayContextProvider =
    FutureProvider<GatewayContext?>((Ref ref) async => null);
