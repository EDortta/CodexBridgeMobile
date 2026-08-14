import 'session.dart';

/// Where the session is kept between launches.
///
/// Named as a store rather than a repository because it holds exactly one
/// value, and that value is a secret: the implementation is expected to be
/// backed by platform secure storage, never by plain preferences.
abstract interface class SessionStore {
  /// The stored session, or `null` when there is none.
  ///
  /// A value that no longer decodes reads as `null`: unreadable local state
  /// means *signed out*, which is the recoverable direction — the operator
  /// signs in again. Throwing here would instead brick the account screen
  /// (`design-standards.md` §6).
  Future<Session?> readSession();

  Future<void> writeSession(Session session);

  /// Removes the stored session. Succeeds whether or not one was there, so a
  /// sign-out can never fail for want of something to remove.
  Future<void> clearSession();
}
