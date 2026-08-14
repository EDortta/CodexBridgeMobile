import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/server_config_store.dart';

/// [SecureKeyValueStore] backed by the platform keystore.
///
/// On Android this is the Keystore-backed encrypted storage that
/// `docs/software-overview.md` requires for local secrets: the plugin wraps an
/// AES-GCM storage key with an RSA key held by the Android Keystore, so the
/// value on disk is not readable from a backup or an extracted data directory.
///
/// Intentionally the thinnest possible adapter — two delegating calls and no
/// decision — because this is the one part of the persistence path that a
/// host-VM test cannot execute. Everything worth asserting lives in
/// `SecureServerConfigStore` instead (`design-standards.md` §1).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
