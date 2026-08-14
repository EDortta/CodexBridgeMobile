import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_providers.dart';
import '../data/mock_auth_gateway.dart';
import '../data/secure_session_store.dart';
import '../domain/auth_gateway.dart';
import '../domain/session.dart';
import '../domain/session_store.dart';
import 'auth_state.dart';

/// Reads the current instant.
///
/// A provider rather than a call to `DateTime.now()` inside the controller,
/// because every branch of the session lifecycle is a statement about time: a
/// hard-coded clock would leave expiry and renewal testable only by waiting for
/// them (`design-standards.md` §2).
typedef Clock = DateTime Function();

final Provider<Clock> sessionClockProvider = Provider<Clock>(
  (Ref ref) => DateTime.timestamp,
);

final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>(
  (Ref ref) => SecureSessionStore(ref.watch(secureKeyValueStoreProvider)),
);

final Provider<AuthGateway> authGatewayProvider = Provider<AuthGateway>(
  (Ref ref) => MockAuthGateway(ref.watch(sessionClockProvider)),
);

final AsyncNotifierProvider<SessionController, AuthState> sessionProvider =
    AsyncNotifierProvider<SessionController, AuthState>(SessionController.new);

/// Owns the session lifecycle: restore, renew, expire, sign in, sign out.
///
/// Every transition into or out of the signed-in state goes through [_grant] or
/// [_revoke], never through a bare `state =`. That is the point: the invariant
/// "what is on screen and what is in the keystore agree" is enforced inside the
/// two operations that can break it, not remembered at each of the five call
/// sites that reach them (`design-standards.md` §3).
class SessionController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final Session? stored = await ref.watch(sessionStoreProvider).readSession();
    if (stored == null) {
      // Nothing to revoke: no session was ever read, so there is nothing on
      // disk this state could disagree with.
      return const SignedOut(reason: SignedOutReason.neverSignedIn);
    }
    return _restore(stored);
  }

  /// Signs in with [accessCode].
  ///
  /// The code is passed straight to the gateway and never kept: it is not
  /// stored, not held in state, and not part of any message this app renders.
  ///
  /// Only from [SignedOut], which is what keeps the invariant above total. A
  /// sign-in over a held session would write `SignedOut` directly on a refusal
  /// — reporting signed out while that session's token is still in the
  /// keystore, the one disagreement [_revoke] exists to prevent.
  Future<void> signIn(String accessCode) async {
    if (state.valueOrNull case SignedOut(
      :final SignedOutReason reason,
      :final bool sessionMayRemainOnDevice,
    )) {
      // `sessionMayRemainOnDevice` is carried through both rebuilds below.
      // Rebuilding without it re-reports a clean device on a keystore that
      // refused the delete, and the retry button is the only in-app way to
      // remove what is still there: a refused sign-in would take away the
      // affordance and leave the tokens.
      state = AsyncData<AuthState>(
        SignedOut(
          reason: reason,
          sessionMayRemainOnDevice: sessionMayRemainOnDevice,
          signingIn: true,
        ),
      );

      final AuthOutcome outcome = await ref
          .read(authGatewayProvider)
          .signIn(accessCode);

      state = AsyncData<AuthState>(
        switch (outcome) {
          AuthGranted(:final Session session) => await _grant(session),
          // The explanation the operator arrived with is kept, so a rejected
          // code does not erase the reason the sign-in screen appeared.
          AuthDenied(reason: final AuthFailure failure) => SignedOut(
            reason: reason,
            failure: failure,
            sessionMayRemainOnDevice: sessionMayRemainOnDevice,
          ),
        },
      );
    }
  }

  /// Renews the held session on the operator's request.
  ///
  /// Does nothing when no session is held: there is nothing to renew, and
  /// inventing one would be a sign-in without a credential.
  Future<void> renew() async {
    if (state.valueOrNull case SignedIn(:final Session session)) {
      state = AsyncData<AuthState>(SignedIn(session, renewing: true));
      state = AsyncData<AuthState>(await _renew(session));
    }
  }

  /// Signs out, clearing the local session state.
  ///
  /// Deliberately callable while already signed out: when a previous removal
  /// was refused by the keystore, this is the retry, and a guard here would
  /// leave the operator with a warning and no way to act on it.
  Future<void> signOut() async {
    final SignedOutReason reason = switch (state.valueOrNull) {
      // Retrying a refused removal is not a second sign-out: the explanation
      // the operator is already reading stays.
      SignedOut(:final SignedOutReason reason) => reason,
      _ => SignedOutReason.signedOut,
    };
    state = AsyncData<AuthState>(await _revoke(reason));
  }

  /// Decides what a session read from storage means right now.
  Future<AuthState> _restore(Session session) async {
    final DateTime now = ref.read(sessionClockProvider)();
    return switch (session.lifecycleAt(now)) {
      SessionLifecycle.active => SignedIn(session),
      SessionLifecycle.renewalDue => _renew(session),
      SessionLifecycle.expired => _revoke(SignedOutReason.sessionExpired),
    };
  }

  Future<AuthState> _renew(Session session) async {
    final AuthOutcome outcome = await ref
        .read(authGatewayProvider)
        .renew(session);

    switch (outcome) {
      case AuthGranted(:final Session session):
        return _grant(session);
      case AuthDenied(reason: final AuthFailure failure):
        final DateTime now = ref.read(sessionClockProvider)();
        // A renewal can fail while the access token is still good — the
        // renewal window opens *before* expiry precisely so there is room to
        // retry. Discarding a session that still works would sign the operator
        // out over one unreachable request.
        final bool stillUsable = !session.isExpiredAt(now);
        // And an unanswered request is not a refusal. The server saying the
        // credential is finished ends the session; the server saying nothing
        // must not destroy a refresh token with days left on it, or opening
        // the app offline costs the operator a sign-in the server never asked
        // for. The refresh window closing is what ends it.
        final bool worthRetrying =
            failure == AuthFailure.unreachable && session.isRenewableAt(now);
        if (stillUsable || worthRetrying) {
          return SignedIn(session);
        }
        return _revoke(SignedOutReason.renewalFailed);
    }
  }

  /// The only way into [SignedIn]: persists first, then reports.
  ///
  /// Ordered this way so the screen can never show a session that a restart
  /// would lose — including when the keystore refuses the write. Auth fails
  /// closed (`design-standards.md` §6): a session this device cannot keep is
  /// reported as no session, in words, rather than shown and quietly lost.
  Future<AuthState> _grant(Session session) async {
    try {
      await ref.read(sessionStoreProvider).writeSession(session);
      return SignedIn(session);
    } on Exception {
      // Whatever was stored before is no longer the session this device holds,
      // so it goes too — and if that removal is also refused, the operator is
      // told rather than left believing the device is clean.
      final bool removed = await _clearStoredSession();
      return SignedOut(
        reason: SignedOutReason.storageUnavailable,
        sessionMayRemainOnDevice: !removed,
      );
    }
  }

  /// The only way out of [SignedIn]: clears the keystore, then reports.
  ///
  /// This is the guard living inside the dangerous operation. Sign-out,
  /// expiry and a failed renewal all land here, so no future path can leave a
  /// token on disk while the app believes it is signed out — and when the
  /// keystore refuses, the state says so instead of the removal failing
  /// silently.
  Future<AuthState> _revoke(SignedOutReason reason) async {
    final bool removed = await _clearStoredSession();
    return SignedOut(reason: reason, sessionMayRemainOnDevice: !removed);
  }

  /// Removes the stored session, reporting whether it is gone.
  ///
  /// The keystore is the one collaborator here that can fail for reasons the
  /// app cannot answer — a Keystore key lost to a backup restore, a device
  /// whose screen lock was removed. Every caller of this class reaches it
  /// through a fire-and-forget tap handler, so a throw escaping here is not an
  /// error anything renders: it is a spinner that never stops and a screen
  /// that never recovers (`design-standards.md` §6).
  Future<bool> _clearStoredSession() async {
    try {
      await ref.read(sessionStoreProvider).clearSession();
      return true;
    } on Exception {
      return false;
    }
  }
}
