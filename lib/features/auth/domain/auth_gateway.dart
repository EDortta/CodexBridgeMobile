import 'session.dart';

/// Issues and renews sessions.
///
/// The seam that lets the whole session lifecycle be exercised without a server
/// (`design-standards.md` §2). The interface is shaped by what this app needs,
/// not by a client library, so when the Codex Bridge authentication contract
/// lands (`EDortta/CodexBridge` issue #4) exactly one file in `data/` changes
/// and nothing above this line moves.
///
/// **Neither method throws.** A refused credential, an unreachable server and a
/// closed refresh window are all [AuthDenied] values, because the caller of a
/// sign-in has to *render* the refusal, not catch it. The promise is stated
/// here so every implementation is held to it, at every entry point
/// (`design-standards.md` §6).
abstract interface class AuthGateway {
  /// Exchanges an operator credential for a session.
  ///
  /// [accessCode] is the credential the operator obtains from their Codex
  /// Bridge account. It is never stored and never logged: it enters here and
  /// leaves as a [Session].
  Future<AuthOutcome> signIn(String accessCode);

  /// Exchanges [session]'s refresh credential for a new session.
  ///
  /// Takes the whole session rather than the bare token because the renewed
  /// session must come back carrying an identity, and the identity is the
  /// server's to confirm.
  Future<AuthOutcome> renew(Session session);
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
