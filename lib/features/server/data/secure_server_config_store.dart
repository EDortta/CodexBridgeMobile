import '../../../core/storage/secure_key_value_store.dart';
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
    final String? stored = await _read();
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

  /// A keystore that cannot be read is a server that cannot be read.
  ///
  /// Mirrors [SecureSessionStore]'s own `_read`: the two features now share
  /// one [SecureKeyValueStore], and a Keystore key lost to a backup restore
  /// makes the plugin throw on *every* key it backs, not just the session's.
  /// Without this, the session screen opens signed-out on that failure while
  /// the server settings screen — reading through the very same store this
  /// class was moved into `core/` to share — has no text field to recover
  /// with, on every launch (`design-standards.md` §3).
  Future<String?> _read() async {
    try {
      return await _storage.read(selectedServerKey);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> writeSelectedServer(ServerUrl server) {
    return _storage.write(selectedServerKey, server.toString());
  }
}
