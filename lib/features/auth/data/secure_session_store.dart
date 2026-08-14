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

  @override
  Future<Session?> readSession() async {
    final String? stored = await _read();
    if (stored == null) {
      return null;
    }

    // The stored string re-enters through the same gate every session passes.
    // A value written by an older build, or one truncated by a crash, reads as
    // "signed out" instead of becoming a Session with fields nobody set.
    return Session.tryDecode(stored);
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

  @override
  Future<void> writeSession(Session session) =>
      _storage.write(sessionKey, session.encode());

  @override
  Future<void> clearSession() => _storage.delete(sessionKey);
}
