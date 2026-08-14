import 'package:codex_bridge_mobile/features/auth/data/secure_session_store.dart';
import 'package:codex_bridge_mobile/features/server/data/secure_server_config_store.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

/// Characterization of issue #21's persistence, written when #22 moved the
/// seam under it.
///
/// `SecureKeyValueStore` left `features/server/` for `core/storage/` so both
/// features could share one platform handle. Nothing pinned this class before
/// that move: `flutter analyze` was the only thing standing behind "the server
/// the operator selected is still there after a restart"
/// (`design-standards.md` §1 — pin untested code *before* refactoring it).
///
/// These describe what the class does today. Not validated here: the platform
/// keystore itself, which no host-VM test can reach — see
/// `FlutterSecureKeyValueStore`, a three-line delegating adapter with no
/// decision in it.
void main() {
  ServerUrl urlOf(String raw) =>
      (ServerUrl.parse(raw) as ServerUrlAccepted).url;

  test('a selected server is read back after the app is restarted', () async {
    // A restart is a new store over the same storage — which is exactly what
    // the provider builds on the next launch.
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    await SecureServerConfigStore(
      storage,
    ).writeSelectedServer(urlOf('https://bridge.example.org:8443/codex'));

    final ServerUrl? restored = await SecureServerConfigStore(
      storage,
    ).readSelectedServer();

    expect(restored.toString(), 'https://bridge.example.org:8443/codex');
  });

  test('the selection goes to secure storage, under its own key', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();

    await SecureServerConfigStore(
      storage,
    ).writeSelectedServer(urlOf('https://bridge.example.org'));

    expect(
      storage.entries.keys,
      <String>[SecureServerConfigStore.selectedServerKey],
    );
  });

  test('the server and the session cannot overwrite each other', () async {
    // The two keys now share one keystore. A collision would have one feature
    // silently erase the other's value, and neither would report anything.
    expect(
      SecureServerConfigStore.selectedServerKey,
      isNot(SecureSessionStore.sessionKey),
    );
  });

  test('no selection reads as no server, not as an error', () async {
    expect(
      await SecureServerConfigStore(
        InMemorySecureKeyValueStore(),
      ).readSelectedServer(),
      isNull,
    );
  });

  test('a stored URL the rules no longer accept reads as no server', () async {
    // A value written by an older build, or one that survived a rule getting
    // stricter, must not come back as a ServerUrl that would never be accepted
    // today (`design-standards.md` §6).
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore(
      <String, String>{
        SecureServerConfigStore.selectedServerKey: 'http://bridge.example.org',
      },
    );

    expect(await SecureServerConfigStore(storage).readSelectedServer(), isNull);
  });
}
