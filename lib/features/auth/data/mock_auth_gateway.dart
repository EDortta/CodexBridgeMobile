import '../domain/auth_gateway.dart';
import '../domain/session.dart';

/// Local stand-in for the Codex Bridge authentication endpoints.
///
/// **This gateway authenticates nobody.** The Codex Bridge backend is an
/// external dependency that is not operated from this repository
/// (`docs/software-overview.md`), and its authentication contract is still
/// unwritten (`EDortta/CodexBridge` issue #4, tracked by
/// `docs/issues/phase-1/README.md`). That epic's own completion criterion says
/// this client holds a fake until the contract exists — so this is the
/// documented interim, in the shape every other feature here already uses
/// (`MockAccountRepository`, `MockMissionRepository`).
///
/// It grants a session for any non-blank username and password, and never
/// checks either against a real registry. What it *does* exercise
/// for real is the part that is this repository's to get right: the lifecycle
/// above it — the windows, the renewal, the expiry, the sign-out — and the
/// Keystore-backed storage under it. Replacing this file with an HTTP client
/// changes nothing else.
///
/// The tokens it mints are visibly synthetic and carry no secret, so a device
/// running this build holds nothing worth stealing.
class MockAuthGateway implements AuthGateway {
  const MockAuthGateway(this._now);

  /// Injected rather than read from `DateTime.now()` inside the methods, so the
  /// lifetimes below are exercisable without waiting for them
  /// (`design-standards.md` §2).
  final DateTime Function() _now;

  /// Short, so the renewal path is reached in ordinary use rather than only
  /// after a day of not opening the app.
  static const Duration accessLifetime = Duration(hours: 1);

  /// The outer bound of the session: once this passes, only a fresh sign-in
  /// recovers.
  static const Duration refreshLifetime = Duration(days: 7);

  @override
  Future<AuthOutcome> signIn({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const AuthDenied(AuthFailure.missingCredential);
    }

    final DateTime now = _now();
    return AuthGranted(
      _sessionAt(now, refreshExpiresAt: now.add(refreshLifetime)),
    );
  }

  @override
  Future<AuthOutcome> renew(Session session) async {
    final DateTime now = _now();
    if (!session.isRenewableAt(now)) {
      return const AuthDenied(AuthFailure.sessionNoLongerRenewable);
    }

    // The refresh window is carried over, never extended: a window that slid
    // forward on every renewal would never close, and the session would outlive
    // any reason to trust the device.
    return AuthGranted(
      _sessionAt(now, refreshExpiresAt: session.refreshExpiresAt),
    );
  }

  Session _sessionAt(DateTime now, {required DateTime refreshExpiresAt}) {
    final String issued = now.toUtc().toIso8601String();
    return Session(
      // Deliberately self-describing rather than random: nothing about this
      // build should look like a credential worth capturing.
      accessToken: 'local-access-$issued',
      refreshToken: 'local-refresh-$issued',
      expiresAt: now.add(accessLifetime),
      refreshExpiresAt: refreshExpiresAt,
      operatorId: localOperatorId,
      operatorName: localOperatorName,
    );
  }

  /// Named so the account this build reports is unmistakably the local one.
  static const String localOperatorId = 'local-operator';
  static const String localOperatorName = 'Local operator (no server)';
}
