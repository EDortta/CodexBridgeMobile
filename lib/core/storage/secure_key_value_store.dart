/// The narrow slice of platform secure storage the application depends on.
///
/// Deliberately three methods wide. The point of the seam is that each caller's
/// *policy* — the key, the encoding, what a corrupt value means — is testable
/// with a fake that implements exactly what the code under test calls, and no
/// stub that is never called (`design-standards.md` §2).
///
/// It lives in `core/` rather than in a feature because two features now store
/// secrets through it — the selected server (#21) and the session (#22) — and a
/// feature must never import another feature
/// (`docs/architecture/state-architecture.md`). One provider also means one
/// override in a test, so a fake cannot be installed for one caller and
/// silently missed for the other.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  /// Removes [key]. Deleting a key that is not there is not an error: a
  /// sign-out must succeed whether or not a session was stored, or the app
  /// would be unable to leave a state it is already in.
  Future<void> delete(String key);
}
