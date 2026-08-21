import '../domain/auth_gateway.dart';
import '../domain/session.dart';

/// What the session screen shows.
///
/// Sealed rather than one class with nullable fields, so "signed in with a
/// sign-in error on screen" and "signed out holding a session" are not states
/// anyone can build by accident (`design-standards.md` §3).
sealed class AuthState {
  const AuthState();
}

/// No session is held on this device.
final class SignedOut extends AuthState {
  const SignedOut({
    required this.reason,
    this.failure,
    this.sessionMayRemainOnDevice = false,
    this.signingIn = false,
    this.serverSessionMayRemainActive = false,
  });

  /// The wording for [sessionMayRemainOnDevice], kept beside the flag rather
  /// than in the screen so no view can invent a softer one for the same fact.
  static const String sessionMayRemainMessage =
      'This device could not remove the stored session, so it may still be '
      'here the next time the app opens. Remove it again to be sure.';

  /// The wording for [serverSessionMayRemainActive], kept beside the flag for
  /// the same reason as [sessionMayRemainMessage].
  static const String serverSessionMayRemainActiveMessage =
      'This device could not confirm the session was ended on the server. It '
      'will still expire on its own, but until then it may still work '
      'elsewhere.';

  /// How the device arrived here — shown as the screen's explanation.
  final SignedOutReason reason;

  /// Why the last sign-in attempt was refused, or `null` when none was made
  /// since arriving here. Shown against the input, not as the explanation, so
  /// the two never overwrite each other.
  final AuthFailure? failure;

  /// The keystore refused to remove the session, so a copy may still be on the
  /// device.
  ///
  /// A third slot rather than another [reason]: *why the operator is signed
  /// out* and *what is still on the device* are different facts, and the second
  /// one has to survive whichever of the first four values brought them here.
  /// `false` means the local state is known to be clean — the app never reports
  /// a clean device on a keystore it could not reach.
  final bool sessionMayRemainOnDevice;

  /// A sign-in is in flight.
  final bool signingIn;

  /// A `signOut` call asked the server to end this device's grant and did not
  /// get a confirmation back — a rejected token, an unreachable gateway, a
  /// timeout.
  ///
  /// A fourth slot rather than reusing [sessionMayRemainOnDevice]: what is
  /// still on *this device* and what is still valid *at the server* are
  /// different facts, checked by different calls, and can disagree in either
  /// direction (`#53`). `false` here covers both "the server confirmed it"
  /// and "there was nothing to ask the server about" — arriving through
  /// [SessionController.build]'s restore path (an expired session, or one a
  /// failed renewal gave up on) reports `false` for the second reason, not
  /// the first: those two paths do not call the server either, the same gap
  /// `signOut` had before `#53`, tracked but not closed by it
  /// (`docs/architecture/security-threat-model.md` R11).
  final bool serverSessionMayRemainActive;
}

/// A session is held, and it is usable.
final class SignedIn extends AuthState {
  const SignedIn(this.session, {this.renewing = false});

  final Session session;

  /// A renewal is in flight. The session stays usable meanwhile.
  final bool renewing;
}

/// Why the device is signed out, with the text the operator reads.
///
/// The distinction the issue asks for is here: an expired session does not
/// silently look like a device that was never signed in. It says what happened,
/// which is what makes the recovery a flow rather than a dead end.
///
/// None of these messages claims the stored copy is gone. Removal is a separate
/// fact that can fail on its own ([SignedOut.sessionMayRemainOnDevice]), and a
/// reason asserting "the session was removed from this device" would contradict
/// the warning shown right under it on the one launch where it matters.
enum SignedOutReason {
  neverSignedIn('Sign in to link this device to your Codex Bridge account.'),
  signedOut(
    'You signed out. Sign in again to use this device with your Codex Bridge '
    'account.',
  ),
  sessionExpired(
    'Your session expired and could no longer be renewed. Sign in again to '
    'continue.',
  ),
  renewalFailed(
    'Your session could not be renewed. Sign in again to continue.',
  ),
  storageUnavailable(
    'This device could not store the session securely, so it was not kept. '
    'Check that the device has a screen lock, then sign in again.',
  );

  const SignedOutReason(this.message);

  final String message;
}
