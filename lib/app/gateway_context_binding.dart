import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gateway/gateway_context.dart';
import '../core/gateway/gateway_context_provider.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/auth_state.dart';
import '../features/server/domain/server_url.dart';
import '../features/server/presentation/server_providers.dart';

/// The real [gatewayContextProvider]: the selected server plus the
/// signed-in session, composed here because `lib/app/` is the one layer
/// allowed to import both `auth` and `server` (`state-architecture.md`).
final Override gatewayContextBinding = gatewayContextProvider.overrideWith(
  (Ref ref) => _resolveGatewayContext(ref),
);

Future<GatewayContext?> _resolveGatewayContext(Ref ref) async {
  final ServerUrl? selectedServer = await _guardStorageRead(
    ref.watch(serverConfigStoreProvider).readSelectedServer(),
  );
  if (selectedServer == null) {
    return null;
  }
  // Not time-bounded like the storage read above: this can include a real
  // network round trip (`SessionController._renew` -> `AuthGateway.renew`),
  // and a fixed short deadline meant for a local keystore read used to fire
  // on ordinary renewal latency too, silently and permanently downgrading a
  // signed-in operator to "not configured" the moment any read here took
  // longer than the deadline — `gatewayContextProvider` is never invalidated,
  // so nothing ever retried (council 2026-08-18, "the adversarial user",
  // reproduced with a 150ms fake renewal). `SessionController` itself already
  // fails closed on a storage error (`design-standards.md` §6), so nothing
  // else here needs to guard against it hanging or throwing.
  final AuthState authState = await ref.watch(sessionProvider.future);
  if (authState case SignedIn(:final Session session)) {
    return GatewayContext(
      server: selectedServer.value,
      accessToken: session.accessToken,
    );
  }
  return null;
}

/// Bounds a secure-storage read so an unreachable keystore reports "nothing
/// selected" instead of hanging the caller: `flutter_secure_storage_linux`
/// can block on Secret Service/D-Bus rather than throwing when no keyring
/// daemon is running, which every host-VM widget test not overriding
/// [serverConfigStoreProvider] would otherwise hit. Deliberately scoped to
/// this one pure-local read — see [_resolveGatewayContext] for why the
/// session read below it is not wrapped the same way.
Future<T?> _guardStorageRead<T extends Object>(Future<T?> future) async {
  try {
    return await future.timeout(const Duration(milliseconds: 100));
  } on TimeoutException {
    return null;
  } on Exception {
    return null;
  }
}
