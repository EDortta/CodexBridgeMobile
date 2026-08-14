import '../../../core/storage/secure_key_value_store.dart';
import '../domain/session.dart';
import '../domain/session_store.dart';

/// Keeps the session in platform secure storage — the Android Keystore-backed
/// storage `docs/software-overview.md` requires for local secrets.
///
/// This class owns the persistence *policy* — the key, and what a value that no
/// longer decodes means — while [SecureKeyValueStore] owns the platform call.
/// That split is what makes the policy testable without a device.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._storage);

  final SecureKeyValueStore _storage;

  /// Namespaced alongside the selected server key (#21) so neither can collide
  /// with the other.
  static const String sessionKey = 'codex_bridge.session';

  /// Set by [clearSession] when the platform delete it attempted throws, and
  /// cleared once a delete succeeds. Read on the next launch so a session the
  /// operator asked to remove — but that the keystore refused to delete — is
  /// not silently restored as an active, usable session with no trace that a
  /// removal was ever attempted (`design-standards.md` §3).
  static const String _pendingRemovalKey = 'codex_bridge.session.pending_removal';

  @override
  Future<Session?> readSession() async {
    final String? stored = await _read();
    if (stored == null) {
      return null;
    }

    if (await _hasPendingRemoval()) {
      // A previous sign-out could not remove this from the keystore. Reading
      // it back as an active session would silently undo a deliberate
      // sign-out on the very next launch; reading it back as nothing stored
      // is the fail-closed direction, same as a value that no longer decodes.
      return null;
    }

    // The stored string re-enters through the same gate every session passes.
    // A value written by an older build, or one truncated by a crash, reads as
    // "signed out" instead of becoming a Session with fields nobody set.
    return Session.tryDecode(stored);
  }

  Future<bool> _hasPendingRemoval() async {
    return await _readPendingRemovalMarker() == 'true';
  }

  Future<String?> _readPendingRemovalMarker() async {
    try {
      return await _storage.read(_pendingRemovalKey);
    } on Exception {
      return null;
    }
  }

  /// A keystore that cannot be read is a session that cannot be read.
  ///
  /// [SessionStore.readSession] promises `null` for local state it cannot make
  /// sense of, and an implementation that throws instead is not that type
  /// (`design-standards.md` §6). The platform failure this covers is real —
  /// a Keystore key lost to a backup restore makes the plugin throw on read —
  /// and the alternative is an account screen that cannot open at all, on
  /// every launch, with no way back. Signed out is the recoverable direction:
  /// the operator signs in again.
  ///
  /// [writeSession] and [clearSession] deliberately keep throwing. There is no
  /// safe value to invent for "the session was not stored" or "the session was
  /// not removed" — those are decisions the caller renders, not failures a
  /// store may swallow.
  Future<String?> _read() async {
    try {
      return await _storage.read(sessionKey);
    } on Exception {
      return null;
    }
  }

  /// Writes [session], and — deliberately — retires any pending-removal
  /// marker left by an earlier refused [clearSession].
  ///
  /// Without this, a fresh grant after a refused removal is written under a
  /// marker [readSession] still honours: the session just persisted here
  /// reads back as null on every later launch, forever, because nothing else
  /// ever clears it once the operator has moved on and stopped calling
  /// [clearSession] (`design-standards.md` §3, the council round-2
  /// pending-removal finding).
  @override
  Future<void> writeSession(Session session) async {
    await _storage.write(sessionKey, session.encode());
    await _clearPendingRemovalMarker();
  }

  /// Removes the stored session. When the platform delete itself fails, marks
  /// the entry as pending removal rather than leaving it silently intact: the
  /// caller is still told the removal failed (this rethrows, same as before),
  /// but [readSession] will not restore it as active in the meantime.
  @override
  Future<void> clearSession() async {
    try {
      await _storage.delete(sessionKey);
    } on Exception {
      await _storage.write(_pendingRemovalKey, 'true');
      rethrow;
    }
    await _clearPendingRemovalMarker();
  }

  /// Retires the pending-removal marker with a *write*, not a delete — and
  /// only when one is actually set, so a device that never hit the failure
  /// never grows this key.
  ///
  /// A delete is exactly the operation the marker exists to route around: the
  /// platform failure this store hardens against is a keystore that refuses
  /// deletes specifically (`DeleteRefusingSecureKeyValueStore` in the test
  /// suite), and on that keystore a delete of this key would fail the same
  /// way the delete of [sessionKey] just did. A write is what already gets
  /// through in that case.
  Future<void> _clearPendingRemovalMarker() async {
    if (await _readPendingRemovalMarker() == null) {
      return;
    }
    try {
      await _storage.write(_pendingRemovalKey, 'false');
    } on Exception {
      // Best effort: the session [writeSession] just wrote, or the delete
      // [clearSession] just completed, is not undone by failing to also
      // clear this marker.
    }
  }
}
