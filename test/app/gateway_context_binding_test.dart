import 'package:codex_bridge_mobile/app/gateway_context_binding.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/features/auth/domain/auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session_store.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_providers.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_config_store.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_url.dart';
import 'package:codex_bridge_mobile/features/server/presentation/server_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [gatewayContextBinding] — the real composition wired into `main.dart` —
/// had zero test coverage before this council: `grep -rln
/// "gateway_context_binding" test/ lib/` returned only `lib/main.dart`
/// (council 2026-08-18, "the claim auditor"). Also pins the fix for the
/// regression that same council found: a fixed 100ms timeout previously
/// bounded the session read too, not just the local storage read, so an
/// ordinary (not hung) renewal slower than 100ms permanently downgraded a
/// signed-in operator to "not configured" — nothing ever invalidates
/// [gatewayContextProvider] to retry.
void main() {
  test('resolves to "not configured" when nothing overrides it', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(gatewayContextProvider.future), isNull);
  });

  test(
    'a session renewal slower than the storage-read timeout still resolves',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 18, 12);
      final Session dueForRenewal = Session(
        accessToken: 'stale-access-token',
        refreshToken: 'refresh-token',
        // Inside Session.renewalLeadTime (5 minutes), so build() renews.
        expiresAt: now.add(const Duration(minutes: 1)),
        refreshExpiresAt: now.add(const Duration(days: 1)),
        operatorId: 'operator-1',
        operatorName: 'Operator One',
      );
      final ServerUrl server =
          (ServerUrl.parse('https://bridge.example.com') as ServerUrlAccepted)
              .url;

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          gatewayContextBinding,
          sessionClockProvider.overrideWithValue(() => now),
          sessionStoreProvider.overrideWithValue(
            _FixedSessionStore(dueForRenewal),
          ),
          serverConfigStoreProvider.overrideWithValue(
            _FixedServerConfigStore(server),
          ),
          authGatewayProvider.overrideWithValue(
            _DelayedRenewalGateway(const Duration(milliseconds: 150), () => now),
          ),
        ],
      );
      addTearDown(container.dispose);

      final GatewayContext? context = await container.read(
        gatewayContextProvider.future,
      );

      expect(context, isNotNull);
      expect(context!.accessToken, 'renewed-access-token');
      expect(context.server, server.value);
    },
  );
}

class _FixedServerConfigStore implements ServerConfigStore {
  const _FixedServerConfigStore(this._url);

  final ServerUrl _url;

  @override
  Future<ServerUrl?> readSelectedServer() async => _url;

  @override
  Future<void> writeSelectedServer(ServerUrl server) async {}
}

class _FixedSessionStore implements SessionStore {
  _FixedSessionStore(this._session);

  Session? _session;

  @override
  Future<Session?> readSession() async => _session;

  @override
  Future<void> writeSession(Session session) async {
    _session = session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}

class _DelayedRenewalGateway implements AuthGateway {
  _DelayedRenewalGateway(this._delay, this._now);

  final Duration _delay;
  final DateTime Function() _now;

  @override
  Future<AuthOutcome> signIn({
    required String username,
    required String password,
  }) async => const AuthDenied(AuthFailure.rejectedCredential);

  @override
  Future<AuthOutcome> renew(Session session) async {
    await Future<void>.delayed(_delay);
    final DateTime now = _now();
    return AuthGranted(
      Session(
        accessToken: 'renewed-access-token',
        refreshToken: session.refreshToken,
        expiresAt: now.add(const Duration(hours: 1)),
        refreshExpiresAt: session.refreshExpiresAt,
        operatorId: session.operatorId,
        operatorName: session.operatorName,
      ),
    );
  }
}
