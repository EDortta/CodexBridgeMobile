import '../domain/server_config_store.dart';
import '../domain/server_url.dart';

/// Remembers the selected server in platform secure storage.
///
/// This class owns the persistence *policy* — the key, the encoding, and what a
/// value that no longer parses means — while [SecureKeyValueStore] owns the
/// platform call. That split is what makes the policy testable without a
/// device.
class SecureServerConfigStore implements ServerConfigStore {
  const SecureServerConfigStore(this._storage);

  final SecureKeyValueStore _storage;

  /// Namespaced so a later key (a session token, issue #22) cannot collide with
  /// this one.
  static const String selectedServerKey = 'codex_bridge.selected_server_url';

  @override
  Future<ServerUrl?> readSelectedServer() async {
    final String? stored = await _storage.read(selectedServerKey);
    if (stored == null) {
      return null;
    }

    // The stored string re-enters through the same gate every typed URL passes.
    // A value written by an older build, or one that survived a rule getting
    // stricter, reads as "no server selected" instead of becoming a ServerUrl
    // that was never accepted.
    final ServerUrlParse parsed = ServerUrl.parse(stored);
    return switch (parsed) {
      ServerUrlAccepted(:final ServerUrl url) => url,
      ServerUrlRejected() => null,
    };
  }

  @override
  Future<void> writeSelectedServer(ServerUrl server) {
    return _storage.write(selectedServerKey, server.toString());
  }
}
