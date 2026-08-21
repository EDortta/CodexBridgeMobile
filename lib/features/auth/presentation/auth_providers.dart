import 'dart:async';

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
  /// Bumped by [signOut]. [renew] captures this when it starts and compares
  /// it again — once after the gateway replies, and again after the outcome
  /// is persisted — discarding the reply if a sign-out has landed in either
  /// window instead of resurrecting the session the operator just removed
  /// (`design-standards.md` §3, the council round-1 and round-2 renew/
  /// sign-out findings).
  int _signOutGeneration = 0;

  /// The in-flight server revoke, when one is running.
  ///
  /// [signOut] is deliberately reachable more than once over the same held
  /// session — the "Remove from this device" retry is exactly that — and
  /// without this, two calls landing before either's network leg resolves
  /// would each fire their own `POST /api/v1/auth/revoke` for the same
  /// session. Harmless to the server (revoking twice is idempotent there) but
  /// not to the operator-facing state: whichever request the server answered
  /// second could report a token the first request already got confirmed as
  /// gone, re-raising [SignedOut.serverSessionMayRemainActive] over a session
  /// that in fact was revoked. Memoizing the call, not the *result*, means a
  /// later, genuinely new sign-out (a fresh sign-in followed by another
  /// sign-out) still fires its own request — this is cleared the moment the
  /// call it is tracking finishes.
  Future<bool>? _pendingRevoke;

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

  /// Signs in with [username] and [password].
  ///
  /// Both are passed straight to the gateway and never kept: neither is
  /// stored, held in state, or part of any message this app renders.
  ///
  /// Only from [SignedOut] with no sign-in already in flight, which is what
  /// keeps the invariant above total. A sign-in over a held session would
  /// write `SignedOut` directly on a refusal — reporting signed out while
  /// that session's token is still in the keystore, the one disagreement
  /// [_revoke] exists to prevent. A second call admitted while the first is
  /// still awaiting the gateway is the same hole reached a different way: two
  /// outcomes race to write `state`, and whichever resolves last wins even if
  /// it is the refusal — so the guard excludes `signingIn: true` too, not just
  /// [SignedIn].
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    if (state.valueOrNull case SignedOut(
      :final SignedOutReason reason,
      :final bool sessionMayRemainOnDevice,
      :final bool serverSessionMayRemainActive,
      signingIn: false,
    )) {
      // `sessionMayRemainOnDevice` and `serverSessionMayRemainActive` are
      // carried through both rebuilds below. Rebuilding without them
      // re-reports a clean device — locally, or at the server — on a removal
      // that refused, and the only in-app trace of that refusal is these two
      // flags; a refused sign-in would erase whichever one this rebuild
      // dropped, with no warning left on screen to say a token might still
      // be live somewhere (`#53`).
      state = AsyncData<AuthState>(
        SignedOut(
          reason: reason,
          sessionMayRemainOnDevice: sessionMayRemainOnDevice,
          serverSessionMayRemainActive: serverSessionMayRemainActive,
          signingIn: true,
        ),
      );

      final AuthOutcome outcome = await ref
          .read(authGatewayProvider)
          .signIn(username: username, password: password);

      state = AsyncData<AuthState>(
        switch (outcome) {
          AuthGranted(:final Session session) => await _grant(session),
          // The explanation the operator arrived with is kept, so a rejected
          // code does not erase the reason the sign-in screen appeared.
          //
          // `sessionMayRemainOnDevice` is re-read from *current* state rather
          // than reusing the value captured above: `signOut` is deliberately
          // callable while this call is in flight (it is the "Remove from
          // this device" retry), and it can resolve the very failure this
          // flag reports — or hit a fresh one — before this gateway call
          // returns. Reusing the stale value would re-raise a warning about a
          // keystore that just went clean, or hide one that just went bad
          // (`design-standards.md` §3).
          AuthDenied(reason: final AuthFailure failure) => SignedOut(
            reason: reason,
            failure: failure,
            sessionMayRemainOnDevice: _currentSessionMayRemainOnDevice(
              orElse: sessionMayRemainOnDevice,
            ),
            // Carried forward for the same reason `sessionMayRemainOnDevice`
            // is, right above: a sign-out's failed revoke can still be
            // unresolved when a sign-in attempt over it is refused, and a
            // rebuild that drops the flag here would silently retire a
            // warning about a server grant nothing has actually confirmed
            // is gone (`#53`, the same shape as the council round-2 finding
            // this file already carries for the device-local flag).
            serverSessionMayRemainActive: _currentServerSessionMayRemainActive(),
          ),
        },
      );
    }
  }

  /// The current [SignedOut.sessionMayRemainOnDevice], or [orElse] when the
  /// state moved on to something that does not carry the flag at all.
  bool _currentSessionMayRemainOnDevice({required bool orElse}) =>
      switch (state.valueOrNull) {
        SignedOut(:final bool sessionMayRemainOnDevice) =>
          sessionMayRemainOnDevice,
        _ => orElse,
      };

  /// Renews the held session on the operator's request.
  ///
  /// Does nothing when no session is held: there is nothing to renew, and
  /// inventing one would be a sign-in without a credential. Also does nothing
  /// while a renewal is already in flight — the guard excludes
  /// `renewing: true` too, not just a state that is not [SignedIn], because a
  /// second call entered before the first resolves would carry the same old
  /// session into a second gateway request, and whichever reply lands last
  /// would win even if it is the stale one.
  Future<void> renew() async {
    if (state.valueOrNull case SignedIn(:final Session session, renewing: false)) {
      final int signOutGeneration = _signOutGeneration;
      state = AsyncData<AuthState>(SignedIn(session, renewing: true));

      final AuthOutcome outcome = await ref
          .read(authGatewayProvider)
          .renew(session);

      if (signOutGeneration != _signOutGeneration) {
        // `signOut` is deliberately unguarded and can land while this
        // renewal is in flight. It already holds `state` and has already
        // cleared the keystore, so granting or denying this reply now would
        // either write a fresh session back after the operator asked to sign
        // out, or clear a keystore entry that is not there to clear
        // (`design-standards.md` §3).
        return;
      }

      final AuthState resolved = await _resolveRenewal(session, outcome);

      if (signOutGeneration != _signOutGeneration) {
        // The same race, one await later: `_resolveRenewal` can itself
        // persist a grant (`_grant` → `writeSession`), and `signOut` can land
        // during *that* await too, after already clearing the keystore. The
        // persist may have already written the renewed session back into a
        // keystore the sign-out just emptied, so skipping the state write
        // alone is not enough this time — the token has to come back out
        // (`design-standards.md` §3, the council round-2 renew/sign-out
        // finding).
        if (resolved is SignedIn) {
          await _clearStoredSession();
        }
        return;
      }

      state = AsyncData<AuthState>(resolved);
    }
  }

  /// Signs out: ends the grant at the server, then clears the local session
  /// state (`#53`).
  ///
  /// Deliberately callable while already signed out: when a previous removal
  /// was refused by the keystore, this is the retry, and a guard here would
  /// leave the operator with a warning and no way to act on it.
  Future<void> signOut() async {
    final AuthState? current = state.valueOrNull;

    if (current case SignedIn(:final Session session)) {
      // Blocks a concurrent `renew` from starting while this sign-out's
      // keystore delete is in flight, reusing the same signal `renew`
      // already checks so the two operations on a held session cannot
      // overlap (`design-standards.md` §3). Renewals already in flight when
      // this starts are handled separately, through `_signOutGeneration`.
      state = AsyncData<AuthState>(SignedIn(session, renewing: true));
    }
    _signOutGeneration++;

    final SignedOutReason reason = switch (current) {
      // Retrying a refused removal is not a second sign-out: the explanation
      // the operator is already reading stays.
      SignedOut(:final SignedOutReason reason) => reason,
      _ => SignedOutReason.signedOut,
    };

    // Ends the server-side grant, alongside the local clear `_revoke` below
    // performs (`#53`). Only attempted when this call is the one holding an
    // actual session to send — a retry of a refused local removal (`current`
    // already `SignedOut`) has no session left in state, and the original
    // call that made this a retry already asked the server once; carrying
    // the prior verdict forward is what keeps that first answer from being
    // silently dropped on the retry (`_currentServerSessionMayRemainActive`).
    //
    // Awaited ahead of the local clear, not raced against it, and never
    // wrapped in a try/catch: `AuthGateway.revoke` is documented to never
    // throw and to resolve inside its own bounded timeout, so this await can
    // only ever produce an outcome — it cannot strand the operator mid
    // sign-out, and its outcome does not gate what follows. That is the
    // fail-open half of this method; the local clear right after it is the
    // fail-closed half, and the two are independent on purpose
    // (`design-standards.md` §6).
    final bool serverSessionMayRemainActive = switch (current) {
      SignedIn(:final Session session) => !await _revokeRemotely(session),
      _ => _currentServerSessionMayRemainActive(),
    };

    state = AsyncData<AuthState>(
      await _revoke(
        reason,
        serverSessionMayRemainActive: serverSessionMayRemainActive,
      ),
    );
  }

  /// The current [SignedOut.serverSessionMayRemainActive], or `false` when
  /// the state moved on to something that does not carry the flag at all —
  /// the same shape as [_currentSigningIn], for the same reason: a value
  /// carried across a rebuild has to be read fresh, not captured before an
  /// await that something else could resolve first.
  bool _currentServerSessionMayRemainActive() => switch (state.valueOrNull) {
    SignedOut(:final bool serverSessionMayRemainActive) =>
      serverSessionMayRemainActive,
    _ => false,
  };

  /// Calls [AuthGateway.revoke] for [session], collapsing any call that lands
  /// while one is already running onto the same in-flight request rather than
  /// firing a second one (see [_pendingRevoke]).
  Future<bool> _revokeRemotely(Session session) {
    final Future<bool>? pending = _pendingRevoke;
    if (pending != null) {
      return pending;
    }
    final Future<bool> started = ref.read(authGatewayProvider).revoke(session);
    _pendingRevoke = started;
    unawaited(
      started.whenComplete(() {
        if (identical(_pendingRevoke, started)) {
          _pendingRevoke = null;
        }
      }),
    );
    return started;
  }

  /// The current [SignedOut.signingIn], or `false` when the state moved on
  /// to something that does not carry the flag at all.
  ///
  /// Read fresh at commit time inside [_revoke] rather than captured once
  /// before its await: a sign-in already in flight must stay guarded, so
  /// [_revoke] must not reset this to the default — but a captured value
  /// goes stale the moment that same sign-in resolves *during* [_revoke]'s
  /// own keystore delete, clearing the flag itself. Reusing the captured
  /// `true` would then write it back over a state where nothing is in
  /// flight anymore, disabling sign-in with no request behind it and no
  /// in-app recovery (`design-standards.md` §3, the council round-2
  /// finding).
  bool _currentSigningIn() => switch (state.valueOrNull) {
    SignedOut(:final bool signingIn) => signingIn,
    _ => false,
  };

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
    return _resolveRenewal(session, outcome);
  }

  Future<AuthState> _resolveRenewal(Session session, AuthOutcome outcome) {
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
          return Future<AuthState>.value(SignedIn(session));
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
  Future<AuthState> _revoke(
    SignedOutReason reason, {
    bool serverSessionMayRemainActive = false,
  }) async {
    final bool removed = await _clearStoredSession();
    return SignedOut(
      reason: reason,
      sessionMayRemainOnDevice: !removed,
      signingIn: _currentSigningIn(),
      serverSessionMayRemainActive: serverSessionMayRemainActive,
    );
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
