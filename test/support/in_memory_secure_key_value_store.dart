import 'package:codex_bridge_mobile/core/storage/secure_key_value_store.dart';

/// [SecureKeyValueStore] that keeps its values in a map.
///
/// Stands in for the Android Keystore, which no host-VM test can reach. It
/// implements exactly the three methods the interface declares and nothing
/// else, so the width of the seam is visible here rather than hidden behind
/// stubs nobody calls (`design-standards.md` §2).
///
/// [entries] is public so a test can assert what is *on disk* — which is the
/// only way to tell "signed out" from "signed out but the token is still
/// there".
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  InMemorySecureKeyValueStore([Map<String, String>? seed])
    : entries = <String, String>{...?seed};

  final Map<String, String> entries;

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);
}

/// A store whose every call fails, for pinning what happens when the platform
/// keystore is unavailable.
class UnavailableSecureKeyValueStore implements SecureKeyValueStore {
  const UnavailableSecureKeyValueStore();

  @override
  Future<String?> read(String key) async => throw const KeystoreUnavailable();

  @override
  Future<void> write(String key, String value) async =>
      throw const KeystoreUnavailable();

  @override
  Future<void> delete(String key) async => throw const KeystoreUnavailable();
}

/// A store that reads, but refuses to write.
///
/// The realistic half-failure: the entry that is already there stays readable
/// while the Keystore key needed to encrypt a *new* value is gone. Separate
/// classes rather than flags on one fake, so each test names the failure it is
/// about.
class WriteRefusingSecureKeyValueStore extends InMemorySecureKeyValueStore {
  WriteRefusingSecureKeyValueStore([super.seed]);

  @override
  Future<void> write(String key, String value) async =>
      throw const KeystoreUnavailable();
}

/// A store that reads and writes, but refuses to delete.
class DeleteRefusingSecureKeyValueStore extends InMemorySecureKeyValueStore {
  DeleteRefusingSecureKeyValueStore([super.seed]);

  @override
  Future<void> delete(String key) async => throw const KeystoreUnavailable();
}

/// What `flutter_secure_storage` raises when the platform refuses: an
/// `Exception`, like the `PlatformException` it stands in for, so a test cannot
/// pass by catching something the real plugin never throws.
class KeystoreUnavailable implements Exception {
  const KeystoreUnavailable();
}
