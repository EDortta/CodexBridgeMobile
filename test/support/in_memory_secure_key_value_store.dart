import 'dart:async';

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

/// A store that reads and writes, but refuses to delete the first time — and
/// only the first time — a given key is deleted.
///
/// Models the realistic recovery case: a transient Keystore failure that is
/// gone by the retry, so `sessionMayRemainOnDevice` should not still be true
/// once the retry actually succeeds.
class DeleteRefusingOnceSecureKeyValueStore extends InMemorySecureKeyValueStore {
  DeleteRefusingOnceSecureKeyValueStore([super.seed]);

  final Set<String> _refused = <String>{};

  @override
  Future<void> delete(String key) async {
    if (_refused.add(key)) {
      throw const KeystoreUnavailable();
    }
    await super.delete(key);
  }
}

/// A store whose `delete` does not resolve until the test releases it.
///
/// Built for the sign-out/renew reentrancy tests: a plain
/// [InMemorySecureKeyValueStore] resolves `delete` synchronously, so a second
/// operation started right after `signOut` never actually lands *during* the
/// keystore call — the race it is meant to close would never show up.
class BlockingDeleteSecureKeyValueStore extends InMemorySecureKeyValueStore {
  BlockingDeleteSecureKeyValueStore([super.seed]);

  final Completer<void> _release = Completer<void>();

  /// Lets a `delete` call already in flight resolve.
  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<void> delete(String key) async {
    await _release.future;
    await super.delete(key);
  }
}

/// A store whose `write` does not resolve until the test releases it.
///
/// Built for the renew/sign-out persist-race test: a plain
/// [InMemorySecureKeyValueStore] resolves `write` synchronously, so a
/// concurrent `signOut` started right after a renewal's gateway call never
/// actually lands *during* the renewal's own keystore write — the race it is
/// meant to close would never show up.
class BlockingWriteSecureKeyValueStore extends InMemorySecureKeyValueStore {
  BlockingWriteSecureKeyValueStore([super.seed]);

  final Completer<void> _release = Completer<void>();
  final Completer<void> _started = Completer<void>();

  /// Resolves once a `write` call is parked and waiting on [release].
  Future<void> get writeStarted => _started.future;

  /// Lets a `write` call already in flight resolve.
  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (!_started.isCompleted) {
      _started.complete();
    }
    await _release.future;
    await super.write(key, value);
  }
}

/// What `flutter_secure_storage` raises when the platform refuses: an
/// `Exception`, like the `PlatformException` it stands in for, so a test cannot
/// pass by catching something the real plugin never throws.
class KeystoreUnavailable implements Exception {
  const KeystoreUnavailable();
}
