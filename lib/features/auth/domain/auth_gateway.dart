import 'session.dart';

/// Issues and renews sessions.
///
/// The seam that lets the whole session lifecycle be exercised without a server
/// (`design-standards.md` §2). The interface is shaped by what this app needs,
/// not by a client library — which is also why [signIn] takes a username and a
/// password rather than the single opaque `accessCode` first drafted here: the
/// Codex Bridge authentication contract that landed (`EDortta/CodexBridge`
/// issue #4) needs both, and the seam is corrected to match rather than left
/// wrong to keep the original prediction ("exactly one file in `data/` changes")
/// true. [renew] took no such correction, so only [HttpAuthGateway] in `data/`,
/// the controller call site and the sign-in screen moved.
///
/// **None of these methods throw.** A refused credential, an unreachable
/// server and a closed refresh window are all [AuthDenied] values, and a
/// failed [revoke] is a `false`, because every caller here is a fire-and-forget
/// tap handler that reports through provider state, not through a caught
/// exception. The promise is stated here so every implementation is held to
/// it, at every entry point (`design-standards.md` §6).
abstract interface class AuthGateway {
  /// Exchanges an operator credential for a session.
  ///
  /// [username] and [password] are the credential the operator holds in the
  /// Codex Bridge user registry. Neither is stored and neither is logged: they
  /// enter here and leave as a [Session].
  ///
  /// Originally shaped as a single opaque `accessCode`, on the assumption the
  /// server would hand out one API-key-style credential
  /// (`EDortta/CodexBridge` issue #4, tracked by `docs/issues/phase-1/README.md`).
  /// The contract that actually landed is `POST /api/v1/auth/sign-in` with a
  /// username *and* a password — the same registry entry the browser OAuth
  /// flow already checks — so the seam is corrected to match rather than
  /// forcing a two-part credential through a one-string parameter.
  Future<AuthOutcome> signIn({
    required String username,
    required String password,
  });

  /// Exchanges [session]'s refresh credential for a new session.
  ///
  /// Takes the whole session rather than the bare token because the renewed
  /// session must come back carrying an identity, and the identity is the
  /// server's to confirm.
  Future<AuthOutcome> renew(Session session);

  /// Ends [session]'s grant on the server, now rather than at its natural
  /// expiry.
  ///
  /// Called by `SessionController.signOut` alongside the local keystore clear
  /// (`#53`): local sign-out completes on this device regardless of what this
  /// returns — the return value is advisory, folded into the operator-facing
  /// state rather than gating anything. `false` covers every way the server
  /// did not confirm it: a rejected token, an unreachable gateway, a timeout.
  Future<bool> revoke(Session session);
}

/// Outcome of a sign-in or a renewal.
sealed class AuthOutcome {
  const AuthOutcome();
}

final class AuthGranted extends AuthOutcome {
  const AuthGranted(this.session);

  final Session session;
}

final class AuthDenied extends AuthOutcome {
  const AuthDenied(this.reason);

  final AuthFailure reason;
}

/// Why a credential did not produce a session, with the text the operator
/// reads.
///
/// The message lives on the reason so no screen can invent a different wording
/// for the same refusal, and so a test can assert the decision without
/// asserting a widget's copy.
enum AuthFailure {
  missingCredential('Enter the access code from your Codex Bridge account.'),
  rejectedCredential(
    'That access code was refused. Request a new one and try again.',
  ),
  sessionNoLongerRenewable(
    'This device can no longer renew its session. Sign in again to continue.',
  ),
  unreachable(
    'The Codex Bridge server did not answer. Check the connection and '
    'try again.',
  );

  const AuthFailure(this.message);

  /// Operator-facing explanation. Carries no input echo, so a pasted credential
  /// cannot reach a screen or a report through it (`AGENTS.md` §3b).
  final String message;
}
