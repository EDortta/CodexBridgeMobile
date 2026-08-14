import 'dart:async';

import 'package:codex_bridge_mobile/core/storage/secure_storage_providers.dart';
import 'package:codex_bridge_mobile/features/auth/data/secure_session_store.dart';
import 'package:codex_bridge_mobile/features/auth/domain/auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_providers.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

/// Grants issued by the sequenced/blocking fakes below. A plain function
/// rather than a field on each fake, so every reentrancy test builds its own
/// distinguishable session without threading `now` through a constructor.
Session _grantedSession(DateTime now, String accessToken) => Session(
  accessToken: accessToken,
  refreshToken: 'granted-refresh-token',
  expiresAt: now.add(const Duration(hours: 1)),
  refreshExpiresAt: now.add(const Duration(days: 7)),
  operatorId: 'operator-1',
  operatorName: 'Operator One',
);

/// Issue #22's lifecycle, end to end, against a fake gateway and a fake
/// keystore: sign in, restore, renew, expire, sign out.
///
/// The clock is injected, so "the session expired" is a value here rather than
/// a wait.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 14, 12);

  Session sessionWith({
    required Duration expiresIn,
    Duration refreshExpiresIn = const Duration(days: 7),
    String accessToken = 'stored-access-token',
  }) {
    return Session(
      accessToken: accessToken,
      refreshToken: 'stored-refresh-token',
      expiresAt: now.add(expiresIn),
      refreshExpiresAt: now.add(refreshExpiresIn),
      operatorId: 'operator-1',
      operatorName: 'Operator One',
    );
  }

  /// Builds a container whose storage, gateway and clock are all fakes.
  ///
  /// [storage] is returned to the caller so a test can assert what is actually
  /// on disk — the only way to tell "signed out" from "signed out with the
  /// token still there".
  ///
  /// [keystore] chooses which fake keystore holds it — the plain one, or one of
  /// the refusing variants, seeded the same way.
  ({ProviderContainer container, InMemorySecureKeyValueStore storage})
  containerWith({
    Session? stored,
    AuthGateway? gateway,
    DateTime? clock,
    InMemorySecureKeyValueStore Function(Map<String, String> seed)? keystore,
  }) {
    final Map<String, String> seed = stored == null
        ? <String, String>{}
        : <String, String>{SecureSessionStore.sessionKey: stored.encode()};
    final InMemorySecureKeyValueStore storage = keystore == null
        ? InMemorySecureKeyValueStore(seed)
        : keystore(seed);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        secureKeyValueStoreProvider.overrideWithValue(storage),
        sessionClockProvider.overrideWithValue(() => clock ?? now),
        if (gateway != null) authGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    return (container: container, storage: storage);
  }

  Future<AuthState> stateOf(ProviderContainer container) =>
      container.read(sessionProvider.future);

  group('restoring a session on launch', () {
    test('no stored session opens signed out, never having signed in', () async {
      final ProviderContainer container = containerWith().container;

      final AuthState state = await stateOf(container);

      expect(state, isA<SignedOut>());
      expect(
        (state as SignedOut).reason,
        SignedOutReason.neverSignedIn,
      );
    });

    test('an active stored session is restored without touching the gateway', () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final ProviderContainer container = containerWith(
        stored: sessionWith(expiresIn: const Duration(hours: 1)),
        gateway: gateway,
      ).container;

      final AuthState state = await stateOf(container);

      expect(state, isA<SignedIn>());
      expect((state as SignedIn).session.accessToken, 'stored-access-token');
      expect(
        gateway.renewals,
        0,
        reason: 'a session that is still good was renewed anyway',
      );
    });

    test('a session inside its renewal window is renewed on launch', () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final result = containerWith(
        stored: sessionWith(
          expiresIn: Session.renewalLeadTime - const Duration(minutes: 1),
        ),
        gateway: gateway,
      );

      final AuthState state = await stateOf(result.container);

      expect(gateway.renewals, 1);
      expect((state as SignedIn).session.accessToken, 'renewed-access-token');
      expect(
        Session.tryDecode(
          result.storage.entries[SecureSessionStore.sessionKey]!,
        )!.accessToken,
        'renewed-access-token',
        reason:
            'the renewed session was shown but not persisted, so the next '
            'launch would renew again from the old one',
      );
    });

    test('an expired session with an open refresh window is renewed', () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final ProviderContainer container = containerWith(
        stored: sessionWith(expiresIn: -const Duration(hours: 2)),
        gateway: gateway,
      ).container;

      final AuthState state = await stateOf(container);

      expect(gateway.renewals, 1);
      expect(state, isA<SignedIn>());
    });
  });

  group('expiry recovers through a stated flow', () {
    test('a session past its refresh window signs out, and says why', () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final result = containerWith(
        stored: sessionWith(
          expiresIn: -const Duration(days: 8),
          refreshExpiresIn: -const Duration(days: 1),
        ),
        gateway: gateway,
      );

      final AuthState state = await stateOf(result.container);

      expect((state as SignedOut).reason, SignedOutReason.sessionExpired);
      expect(
        state.reason.message,
        isNotEmpty,
        reason:
            'an expired session that reads like a device that never signed in '
            'is a dead end, not a recovery flow',
      );
      expect(
        gateway.renewals,
        0,
        reason: 'a closed refresh window was still sent to the gateway',
      );
      expect(
        result.storage.entries,
        isEmpty,
        reason: 'an unusable session was left in the keystore',
      );
    });

    test('a refused renewal on an expired session signs out and clears', () async {
      final result = containerWith(
        stored: sessionWith(expiresIn: -const Duration(hours: 2)),
        gateway: _FakeAuthGateway(
          renewOutcome: const AuthDenied(AuthFailure.sessionNoLongerRenewable),
        ),
      );

      final AuthState state = await stateOf(result.container);

      expect((state as SignedOut).reason, SignedOutReason.renewalFailed);
      expect(result.storage.entries, isEmpty);
    });

    test('a refused renewal on a still-valid session keeps the session', () async {
      // The renewal window opens *before* expiry precisely so there is room to
      // retry. Signing the operator out over one unreachable request would
      // discard a session that still works.
      final Session stored = sessionWith(
        expiresIn: Session.renewalLeadTime - const Duration(minutes: 1),
      );
      final result = containerWith(
        stored: stored,
        gateway: _FakeAuthGateway(
          renewOutcome: const AuthDenied(AuthFailure.unreachable),
        ),
      );

      final AuthState state = await stateOf(result.container);

      expect(state, isA<SignedIn>());
      expect((state as SignedIn).session.accessToken, stored.accessToken);
      expect(
        result.storage.entries[SecureSessionStore.sessionKey],
        isNotNull,
        reason: 'a usable session was cleared because a renewal failed',
      );
    });

    test('an unreachable server does not destroy a still-renewable session', () async {
      // The operator opens the app offline two hours after last use: the access
      // token has expired, the refresh window is open for six more days. A
      // server that did not answer said nothing about the credential, and
      // discarding it here costs a sign-in the server never asked for.
      final Session stored = sessionWith(expiresIn: -const Duration(hours: 2));
      final result = containerWith(
        stored: stored,
        gateway: _FakeAuthGateway(
          renewOutcome: const AuthDenied(AuthFailure.unreachable),
        ),
      );

      final AuthState state = await stateOf(result.container);

      expect(state, isA<SignedIn>());
      expect((state as SignedIn).session.refreshToken, stored.refreshToken);
      expect(
        result.storage.entries[SecureSessionStore.sessionKey],
        isNotNull,
        reason:
            'a refresh token with days left was erased because one request '
            'went unanswered',
      );
    });

    test('a server that refuses the refresh token ends the session', () async {
      // The other half of the rule above: a refusal *is* an answer. Only an
      // unanswered request buys the session more time.
      final result = containerWith(
        stored: sessionWith(expiresIn: -const Duration(hours: 2)),
        gateway: _FakeAuthGateway(
          renewOutcome: const AuthDenied(AuthFailure.rejectedCredential),
        ),
      );

      final AuthState state = await stateOf(result.container);

      expect((state as SignedOut).reason, SignedOutReason.renewalFailed);
      expect(result.storage.entries, isEmpty);
    });
  });

  group('signing in', () {
    test('a granted code signs in and persists the session', () async {
      final result = containerWith(gateway: _FakeAuthGateway());
      await stateOf(result.container);

      await result.container
          .read(sessionProvider.notifier)
          .signIn('an-access-code');

      final AuthState state = result.container.read(sessionProvider).value!;
      expect(state, isA<SignedIn>());
      expect(
        result.storage.entries[SecureSessionStore.sessionKey],
        isNotNull,
        reason: 'the session was shown but not stored, so a restart loses it',
      );
    });

    test('a refused code stays signed out and reports the refusal', () async {
      final result = containerWith(
        gateway: _FakeAuthGateway(
          signInOutcome: const AuthDenied(AuthFailure.rejectedCredential),
        ),
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signIn('wrong');

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(state.failure, AuthFailure.rejectedCredential);
      expect(
        state.reason,
        SignedOutReason.neverSignedIn,
        reason:
            'the refusal overwrote the explanation the operator arrived with',
      );
      expect(result.storage.entries, isEmpty);
    });

    test('a refused code after an expiry keeps the expiry explanation', () async {
      final result = containerWith(
        stored: sessionWith(
          expiresIn: -const Duration(days: 8),
          refreshExpiresIn: -const Duration(days: 1),
        ),
        gateway: _FakeAuthGateway(
          signInOutcome: const AuthDenied(AuthFailure.rejectedCredential),
        ),
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signIn('wrong');

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(state.reason, SignedOutReason.sessionExpired);
      expect(state.failure, AuthFailure.rejectedCredential);
    });

    test('the access code is handed to the gateway and kept nowhere', () async {
      const String code = 'SECRET-ACCESS-CODE';
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final result = containerWith(gateway: gateway);
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signIn(code);

      expect(gateway.codes, <String>[code]);
      expect(
        result.storage.entries.values.join(),
        isNot(contains(code)),
        reason: 'the credential was persisted; only the session it bought is',
      );
    });

    test('a sign-in while a session is held cannot strand its token', () async {
      // `signIn` is the one entry point that writes SignedOut without going
      // through `_revoke`. Called over a held session, a refusal would report
      // signed out while that session's token stayed in the keystore. It is
      // not reachable from today's screen; the guard is what keeps that true
      // of the next one (`design-standards.md` §3).
      final _FakeAuthGateway gateway = _FakeAuthGateway(
        signInOutcome: const AuthDenied(AuthFailure.rejectedCredential),
      );
      final result = containerWith(
        stored: sessionWith(expiresIn: const Duration(hours: 1)),
        gateway: gateway,
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signIn('wrong');

      expect(result.container.read(sessionProvider).value, isA<SignedIn>());
      expect(gateway.codes, isEmpty);
      expect(
        result.storage.entries[SecureSessionStore.sessionKey],
        isNotNull,
        reason:
            'the app reported signed out while the session it held was still '
            'in the keystore',
      );
    });

    test(
      'a second sign-in cannot land while the first is still in flight',
      () async {
        // The guard that keeps `signIn` off `SignedIn` (above) only stops a
        // second call once the first has landed. Two calls entered close
        // together both read `SignedOut` before either writes state, so both
        // proceed — and whichever gateway reply resolves last wins, even if
        // it is a refusal arriving after the other call already granted and
        // stored a session. `state.signingIn` was already there to disable
        // the button; the fix is making the guard itself honor it.
        final Completer<AuthOutcome> firstOutcome = Completer<AuthOutcome>();
        final Completer<AuthOutcome> secondOutcome = Completer<AuthOutcome>();
        final _SequencedAuthGateway gateway = _SequencedAuthGateway(
          <Completer<AuthOutcome>>[firstOutcome, secondOutcome],
        );
        final result = containerWith(gateway: gateway);
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );

        final Future<void> first = notifier.signIn('first-code');
        final Future<void> second = notifier.signIn('second-code');

        // The grant lands, and is fully persisted and shown, before the
        // refusal for the other call is even produced.
        firstOutcome.complete(
          AuthGranted(
            Session(
              accessToken: 'granted-access-token',
              refreshToken: 'granted-refresh-token',
              expiresAt: now.add(const Duration(hours: 1)),
              refreshExpiresAt: now.add(const Duration(days: 7)),
              operatorId: 'operator-1',
              operatorName: 'Operator One',
            ),
          ),
        );
        await first;
        secondOutcome.complete(
          const AuthDenied(AuthFailure.rejectedCredential),
        );
        await second;

        final AuthState state = result.container.read(sessionProvider).value!;
        expect(
          state,
          isA<SignedIn>(),
          reason:
              'a refusal that arrived after the grant overwrote the granted '
              'session, reporting signed out while its token stayed in the '
              'keystore',
        );
        expect(
          result.storage.entries[SecureSessionStore.sessionKey],
          isNotNull,
        );
      },
    );

    test(
      'a sign-out taken while a sign-in is in flight keeps the guard closed',
      () async {
        // `signOut` is the "Remove from this device" retry and is
        // deliberately reachable while a sign-in is in flight. Rebuilding
        // `SignedOut` without carrying `signingIn` would reopen the guard
        // above and reintroduce the exact race it closes, reached through
        // the one caller that writes `SignedOut` without going through it.
        final Completer<AuthOutcome> outcome = Completer<AuthOutcome>();
        final _SequencedAuthGateway gateway = _SequencedAuthGateway(
          <Completer<AuthOutcome>>[outcome],
        );
        final result = containerWith(gateway: gateway);
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );

        final Future<void> signingIn = notifier.signIn('first-code');
        await notifier.signOut();

        expect(
          (result.container.read(sessionProvider).value! as SignedOut)
              .signingIn,
          isTrue,
          reason:
              'signOut cleared signingIn while the sign-in it belongs to '
              'was still in flight',
        );

        await notifier.signIn('second-code');

        expect(
          gateway.calls,
          1,
          reason:
              'a second sign-in reached the gateway while the first was '
              'still in flight',
        );

        outcome.complete(AuthGranted(_grantedSession(now, 'granted-access-token')));
        await signingIn;

        final AuthState state = result.container.read(sessionProvider).value!;
        expect(state, isA<SignedIn>());
        expect(
          result.storage.entries[SecureSessionStore.sessionKey],
          isNotNull,
        );
      },
    );

    test(
      'a sign-in that resolves before the sign-out delete does is not '
      'reopened stale',
      () async {
        // The mirror image of the test above: there, `signOut`'s write
        // landed *before* the sign-in it belongs to resolved, and carrying
        // `signingIn` through fixed it. Here the sign-in resolves *first* —
        // clearing `signingIn` itself, correctly — while `signOut`'s own
        // keystore delete is still in flight. `signOut` captured
        // `signingIn: true` before that delete started and never re-reads
        // it, so its late write puts the stale `true` back onto a state
        // where nothing is in flight anymore: a spinner with no request
        // behind it, and `signIn` guarded off forever with no in-app
        // recovery (`design-standards.md` §3, the council round-2 finding).
        final Completer<AuthOutcome> outcome = Completer<AuthOutcome>();
        final _SequencedAuthGateway gateway = _SequencedAuthGateway(
          <Completer<AuthOutcome>>[outcome],
        );
        final result = containerWith(
          gateway: gateway,
          keystore: BlockingDeleteSecureKeyValueStore.new,
        );
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );
        final BlockingDeleteSecureKeyValueStore storage =
            result.storage as BlockingDeleteSecureKeyValueStore;

        final Future<void> signingIn = notifier.signIn('a-code');
        final Future<void> signingOut = notifier.signOut();

        // The sign-in is refused before the sign-out's delete resolves.
        outcome.complete(const AuthDenied(AuthFailure.rejectedCredential));
        await signingIn;
        expect(
          (result.container.read(sessionProvider).value! as SignedOut)
              .signingIn,
          isFalse,
          reason: "the sign-in's own write correctly cleared the flag",
        );

        storage.release();
        await signingOut;

        final SignedOut state =
            result.container.read(sessionProvider).value! as SignedOut;
        expect(
          state.signingIn,
          isFalse,
          reason:
              "signOut's late write put back a signingIn it captured "
              'before its own await, over a sign-in that had already '
              'finished and cleared it',
        );
      },
    );
  });

  group('signing out', () {
    test('sign-out clears the local session state', () async {
      final result = containerWith(
        stored: sessionWith(expiresIn: const Duration(hours: 1)),
        gateway: _FakeAuthGateway(),
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signOut();

      final AuthState state = result.container.read(sessionProvider).value!;
      expect((state as SignedOut).reason, SignedOutReason.signedOut);
      expect(
        result.storage.entries,
        isEmpty,
        reason:
            'the app reported signed out while the token was still in the '
            'keystore — the state on screen and the state on disk disagree',
      );
    });

  });

  group('a keystore that refuses is reported, never dropped', () {
    // Every one of these paths is reached from a fire-and-forget tap handler:
    // the screen calls the controller and renders provider state, so an error
    // that escapes the controller is not rendered anywhere. It leaves a spinner
    // running, both buttons disabled, and no way out short of killing the app.
    // What the operator must get instead is a *state*.

    test('a launch that cannot read the keystore opens signed out, not broken', () async {
      // A Keystore key lost to a backup restore makes the plugin throw on read.
      // Bricking the account screen on every launch is not the fail-closed
      // direction — signing out is (`design-standards.md` §6).
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          secureKeyValueStoreProvider.overrideWithValue(
            const UnavailableSecureKeyValueStore(),
          ),
          sessionClockProvider.overrideWithValue(() => now),
          authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
        ],
      );
      addTearDown(container.dispose);

      final AuthState state = await stateOf(container);

      expect((state as SignedOut).reason, SignedOutReason.neverSignedIn);
    });

    test('a sign-in the keystore will not store reports not signed in', () async {
      final result = containerWith(
        gateway: _FakeAuthGateway(),
        keystore: WriteRefusingSecureKeyValueStore.new,
      );
      await stateOf(result.container);

      await result.container
          .read(sessionProvider.notifier)
          .signIn('an-access-code');

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(
        state.reason,
        SignedOutReason.storageUnavailable,
        reason:
            'a session the device cannot keep was reported as signed in; the '
            'next launch loses it with no explanation',
      );
      expect(
        state.signingIn,
        isFalse,
        reason:
            'the sign-in button stays disabled behind a spinner that never '
            'stops',
      );
      expect(result.storage.entries, isEmpty);
    });

    test('a renewal the keystore will not store does not show a lost session', () async {
      final result = containerWith(
        stored: sessionWith(
          expiresIn: Session.renewalLeadTime - const Duration(minutes: 1),
        ),
        gateway: _FakeAuthGateway(),
        keystore: WriteRefusingSecureKeyValueStore.new,
      );

      final AuthState state = await stateOf(result.container);

      expect((state as SignedOut).reason, SignedOutReason.storageUnavailable);
      expect(
        result.storage.entries,
        isEmpty,
        reason:
            'the superseded session was left behind, so the app shows signed '
            'out while its token is still in the keystore',
      );
    });

    test('a sign-out the keystore will not clear says the session may remain', () async {
      // Reporting "signed out" while the token is still on disk is the one
      // outcome worse than a visible failure: the operator believes the device
      // is clean and it is not.
      final result = containerWith(
        stored: sessionWith(expiresIn: const Duration(hours: 1)),
        gateway: _FakeAuthGateway(),
        keystore: DeleteRefusingSecureKeyValueStore.new,
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signOut();

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(
        state.sessionMayRemainOnDevice,
        isTrue,
        reason:
            'the app reported a clean device on a keystore it could not '
            'reach',
      );
      expect(state.reason, SignedOutReason.signedOut);
      expect(
        result.storage.entries[SecureSessionStore.sessionKey],
        isNotNull,
        reason: 'the fake refused the delete; the state must match the device',
      );
    });

    test('an expiry the keystore will not clear keeps the expiry explanation', () async {
      // Two different facts: *why* the operator is signed out, and *what is
      // still on the device*. One must not overwrite the other.
      final result = containerWith(
        stored: sessionWith(
          expiresIn: -const Duration(days: 8),
          refreshExpiresIn: -const Duration(days: 1),
        ),
        gateway: _FakeAuthGateway(),
        keystore: DeleteRefusingSecureKeyValueStore.new,
      );

      final SignedOut state = await stateOf(result.container) as SignedOut;

      expect(state.reason, SignedOutReason.sessionExpired);
      expect(state.sessionMayRemainOnDevice, isTrue);
    });

    test('removing again after a refused removal keeps the same explanation', () async {
      // The warning tells the operator to try again, and the retry is
      // `signOut` a second time — which must not relabel an expiry as a
      // deliberate sign-out.
      final result = containerWith(
        stored: sessionWith(
          expiresIn: -const Duration(days: 8),
          refreshExpiresIn: -const Duration(days: 1),
        ),
        gateway: _FakeAuthGateway(),
        keystore: DeleteRefusingSecureKeyValueStore.new,
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signOut();

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(state.reason, SignedOutReason.sessionExpired);
      expect(state.sessionMayRemainOnDevice, isTrue);
    });

    test('a refused sign-in after a refused removal still says a session may remain', () async {
      // The two states above are each covered alone, and the defect lived in
      // the sequence: `signIn` rebuilt `SignedOut` without carrying the flag,
      // so the warning and the "Remove from this device" retry disappeared
      // while both tokens were still in the keystore. A restart was the only
      // way to get the affordance back.
      final result = containerWith(
        stored: sessionWith(
          expiresIn: -const Duration(days: 8),
          refreshExpiresIn: -const Duration(days: 1),
        ),
        gateway: _FakeAuthGateway(
          signInOutcome: const AuthDenied(AuthFailure.rejectedCredential),
        ),
        keystore: DeleteRefusingSecureKeyValueStore.new,
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).signIn('wrong');

      final SignedOut state =
          result.container.read(sessionProvider).value! as SignedOut;
      expect(
        state.sessionMayRemainOnDevice,
        isTrue,
        reason: 'a refused code cannot turn an unreachable keystore into a clean device',
      );
      expect(state.failure, isNotNull, reason: 'the refusal is still reported');
      expect(
        state.reason,
        SignedOutReason.sessionExpired,
        reason: 'and the explanation the operator arrived with survives',
      );
    });

    test(
      'a refusal landing after a successful removal does not re-raise the leftover warning',
      () async {
        // The removal that failed on launch is retried by `signOut` while a
        // sign-in is in flight, and this time it succeeds. `signIn`'s denial
        // branch must report the device as it is *now*, not as it was when
        // the call started.
        final Completer<AuthOutcome> outcome = Completer<AuthOutcome>();
        final _SequencedAuthGateway gateway = _SequencedAuthGateway(
          <Completer<AuthOutcome>>[outcome],
        );
        final result = containerWith(
          stored: sessionWith(
            expiresIn: -const Duration(days: 8),
            refreshExpiresIn: -const Duration(days: 1),
          ),
          gateway: gateway,
          keystore: DeleteRefusingOnceSecureKeyValueStore.new,
        );
        final AuthState built = await stateOf(result.container);
        expect((built as SignedOut).sessionMayRemainOnDevice, isTrue);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );

        final Future<void> signingIn = notifier.signIn('wrong-code');
        await notifier.signOut();

        expect(
          (result.container.read(sessionProvider).value! as SignedOut)
              .sessionMayRemainOnDevice,
          isFalse,
          reason: 'the retry succeeded but the warning was not cleared',
        );

        outcome.complete(const AuthDenied(AuthFailure.rejectedCredential));
        await signingIn;

        final SignedOut state =
            result.container.read(sessionProvider).value! as SignedOut;
        expect(
          state.sessionMayRemainOnDevice,
          isFalse,
          reason:
              'a refusal that arrived after a successful removal re-raised '
              'the leftover warning on a keystore that is now empty',
        );
      },
    );
  });

  group('renewing on request', () {
    test('renew replaces the session and persists it', () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final result = containerWith(
        stored: sessionWith(expiresIn: const Duration(hours: 1)),
        gateway: gateway,
      );
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).renew();

      final SignedIn state =
          result.container.read(sessionProvider).value! as SignedIn;
      expect(state.session.accessToken, 'renewed-access-token');
      expect(state.renewing, isFalse);
      expect(
        Session.tryDecode(
          result.storage.entries[SecureSessionStore.sessionKey]!,
        )!.accessToken,
        'renewed-access-token',
      );
    });

    test('renew does nothing when no session is held', () async {
      // Minting a session without a credential is a sign-in with no sign-in.
      final _FakeAuthGateway gateway = _FakeAuthGateway();
      final result = containerWith(gateway: gateway);
      await stateOf(result.container);

      await result.container.read(sessionProvider.notifier).renew();

      expect(gateway.renewals, 0);
      expect(result.container.read(sessionProvider).value, isA<SignedOut>());
      expect(result.storage.entries, isEmpty);
    });

    test(
      'a second renewal cannot land while the first is still in flight',
      () async {
        // Same shape as sign-in's reentrancy guard: two calls entered close
        // together both read `renewing: false` before either writes state
        // unless the guard itself checks it, and both would carry the same
        // old session into a second gateway request.
        final Completer<AuthOutcome> outcome = Completer<AuthOutcome>();
        final _SequencedRenewalGateway gateway = _SequencedRenewalGateway(
          <Completer<AuthOutcome>>[outcome],
        );
        final result = containerWith(
          stored: sessionWith(expiresIn: const Duration(hours: 1)),
          gateway: gateway,
        );
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );

        final Future<void> first = notifier.renew();
        final Future<void> second = notifier.renew();

        outcome.complete(AuthGranted(_grantedSession(now, 'renewed-access-token')));
        await first;
        await second;

        expect(
          gateway.calls,
          1,
          reason: 'a second renewal reached the gateway while the first was '
              'still in flight',
        );
        final SignedIn state =
            result.container.read(sessionProvider).value! as SignedIn;
        expect(state.session.accessToken, 'renewed-access-token');
      },
    );

    test(
      'a sign-out taken while a renewal is in flight is not undone',
      () async {
        final Completer<AuthOutcome> outcome = Completer<AuthOutcome>();
        final _SequencedRenewalGateway gateway = _SequencedRenewalGateway(
          <Completer<AuthOutcome>>[outcome],
        );
        final result = containerWith(
          stored: sessionWith(expiresIn: const Duration(hours: 1)),
          gateway: gateway,
        );
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );

        final Future<void> renewing = notifier.renew();
        await notifier.signOut();

        // The grant lands only after the sign-out has already committed.
        outcome.complete(AuthGranted(_grantedSession(now, 'renewed-access-token')));
        await renewing;

        final AuthState state = result.container.read(sessionProvider).value!;
        expect(
          state,
          isA<SignedOut>(),
          reason:
              'a renewal that landed after a sign-out resurrected the '
              'session the operator had just removed',
        );
        expect(
          result.storage.entries,
          isEmpty,
          reason:
              'the late grant persisted a session the operator had just '
              'removed',
        );
      },
    );

    test(
      'a sign-out landing during the renewal persist is not undone',
      () async {
        // The council round-2 finding: the sign-out taken while a renewal is
        // in flight is guarded at the gateway await (the test above), but
        // `_resolveRenewal` has a *second* await — the persist inside
        // `_grant` — and a sign-out landing there was never re-checked. The
        // renewal's own write could land after the sign-out had already
        // cleared the keystore, putting a token back that the operator had
        // just watched disappear.
        final _FakeAuthGateway gateway = _FakeAuthGateway();
        final result = containerWith(
          stored: sessionWith(expiresIn: const Duration(hours: 1)),
          gateway: gateway,
          keystore: BlockingWriteSecureKeyValueStore.new,
        );
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );
        final BlockingWriteSecureKeyValueStore storage =
            result.storage as BlockingWriteSecureKeyValueStore;

        final Future<void> renewing = notifier.renew();
        // Let the renewal's gateway call resolve and its persist actually
        // start before the sign-out lands, or the race being tested never
        // happens.
        await storage.writeStarted;
        final Future<void> signingOut = notifier.signOut();
        storage.release();
        await renewing;
        await signingOut;

        final AuthState state = result.container.read(sessionProvider).value!;
        expect(
          state,
          isA<SignedOut>(),
          reason:
              'a renewal whose persist landed after a sign-out resurrected '
              'the session the operator had just removed',
        );
        expect(
          result.storage.entries,
          isEmpty,
          reason:
              'the renewal write landed after the sign-out cleared the '
              'keystore, leaving a token behind that the operator was told '
              'was gone',
        );
      },
    );

    test(
      'a renewal cannot start while a sign-out delete is in flight',
      () async {
        final _FakeAuthGateway gateway = _FakeAuthGateway();
        final result = containerWith(
          stored: sessionWith(expiresIn: const Duration(hours: 1)),
          gateway: gateway,
          keystore: BlockingDeleteSecureKeyValueStore.new,
        );
        await stateOf(result.container);
        final SessionController notifier = result.container.read(
          sessionProvider.notifier,
        );
        final BlockingDeleteSecureKeyValueStore storage =
            result.storage as BlockingDeleteSecureKeyValueStore;

        final Future<void> signingOut = notifier.signOut();
        await notifier.renew();

        expect(
          gateway.renewals,
          0,
          reason:
              'a renewal reached the gateway while the sign-out delete was '
              'still in flight',
        );

        storage.release();
        await signingOut;

        final SignedOut state =
            result.container.read(sessionProvider).value! as SignedOut;
        expect(state.reason, SignedOutReason.signedOut);
      },
    );
  });

  group('a relaunch after a refused removal', () {
    test(
      'does not restore the session the operator asked to remove',
      () async {
        final DeleteRefusingSecureKeyValueStore storage =
            DeleteRefusingSecureKeyValueStore(<String, String>{
              SecureSessionStore.sessionKey: sessionWith(
                expiresIn: const Duration(hours: 1),
              ).encode(),
            });

        final ProviderContainer first = ProviderContainer(
          overrides: <Override>[
            secureKeyValueStoreProvider.overrideWithValue(storage),
            sessionClockProvider.overrideWithValue(() => now),
            authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
          ],
        );
        addTearDown(first.dispose);
        await first.read(sessionProvider.future);
        await first.read(sessionProvider.notifier).signOut();
        final SignedOut afterSignOut =
            first.read(sessionProvider).value! as SignedOut;
        expect(
          afterSignOut.sessionMayRemainOnDevice,
          isTrue,
          reason: 'the fake refused the delete; the removal really failed',
        );

        // A relaunch is a new container over the same keystore.
        final ProviderContainer second = ProviderContainer(
          overrides: <Override>[
            secureKeyValueStoreProvider.overrideWithValue(storage),
            sessionClockProvider.overrideWithValue(() => now),
            authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
          ],
        );
        addTearDown(second.dispose);

        final AuthState relaunched = await second.read(sessionProvider.future);

        expect(
          relaunched,
          isA<SignedOut>(),
          reason:
              'the operator signed out; the next launch restored the '
              'session that could not be removed, with no trace of the '
              'sign-out',
        );
      },
    );

    test(
      'a sign-in that succeeds after a refused removal survives the next '
      'launch',
      () async {
        // The council round-2 finding on the fix above: the pending-removal
        // marker `clearSession` writes on a refused delete is retired only
        // by a later *successful* `clearSession` — `writeSession` never
        // touched it. An ordinary sign-in-again after the refused removal
        // (no race, two plain taps) persisted a brand-new session under a
        // marker nothing but a delete this keystore keeps refusing would
        // ever clear, so the fresh sign-in was silently dropped on every
        // later launch while its token stayed in the keystore, unread and
        // unremovable (`design-standards.md` §3).
        final DeleteRefusingSecureKeyValueStore storage =
            DeleteRefusingSecureKeyValueStore(<String, String>{
              SecureSessionStore.sessionKey: sessionWith(
                expiresIn: const Duration(hours: 1),
              ).encode(),
            });

        final ProviderContainer first = ProviderContainer(
          overrides: <Override>[
            secureKeyValueStoreProvider.overrideWithValue(storage),
            sessionClockProvider.overrideWithValue(() => now),
            authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
          ],
        );
        addTearDown(first.dispose);
        await first.read(sessionProvider.future);
        await first.read(sessionProvider.notifier).signOut();
        expect(
          (first.read(sessionProvider).value! as SignedOut)
              .sessionMayRemainOnDevice,
          isTrue,
          reason: 'the fake refused the delete; the removal really failed',
        );

        await first.read(sessionProvider.notifier).signIn('good-code');
        expect(
          first.read(sessionProvider).value,
          isA<SignedIn>(),
          reason: 'the fresh sign-in was granted',
        );

        // A relaunch is a new container over the same keystore.
        final ProviderContainer second = ProviderContainer(
          overrides: <Override>[
            secureKeyValueStoreProvider.overrideWithValue(storage),
            sessionClockProvider.overrideWithValue(() => now),
            authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
          ],
        );
        addTearDown(second.dispose);

        final AuthState relaunched = await second.read(sessionProvider.future);

        expect(
          relaunched,
          isA<SignedIn>(),
          reason:
              'the operator signed in successfully after the refused '
              'removal; the next launch dropped that session on the floor '
              'while its token stayed in the keystore',
        );
      },
    );
  });
}

/// Gateway whose sign-in replies resolve on the test's own schedule, one
/// [Completer] per call in call order.
///
/// Built for `signIn`'s reentrancy test: a plain [_FakeAuthGateway] resolves
/// synchronously, so two overlapping calls always finish in submission
/// order and the race never shows up. Real network calls do not make that
/// promise, and neither does this fake.
class _SequencedAuthGateway implements AuthGateway {
  _SequencedAuthGateway(this._outcomes);

  final List<Completer<AuthOutcome>> _outcomes;
  int _calls = 0;

  /// How many sign-ins actually reached the gateway — a call the guard
  /// blocked never reaches [signIn] at all, so this is the direct evidence
  /// that the guard held.
  int get calls => _calls;

  @override
  Future<AuthOutcome> signIn(String accessCode) => _outcomes[_calls++].future;

  @override
  Future<AuthOutcome> renew(Session session) => throw UnimplementedError();
}

/// Gateway whose renewal replies resolve on the test's own schedule, one
/// [Completer] per call in call order.
///
/// Built for `renew`'s reentrancy tests, the same reason
/// [_SequencedAuthGateway] exists for `signIn`: a plain [_FakeAuthGateway]
/// resolves synchronously, so an overlapping second call never actually lands
/// while the first is still in flight and the race never shows up.
class _SequencedRenewalGateway implements AuthGateway {
  _SequencedRenewalGateway(this._outcomes);

  final List<Completer<AuthOutcome>> _outcomes;
  int _calls = 0;

  /// How many renewals actually reached the gateway — a call the guard
  /// blocked never reaches [renew] at all.
  int get calls => _calls;

  @override
  Future<AuthOutcome> signIn(String accessCode) => throw UnimplementedError();

  @override
  Future<AuthOutcome> renew(Session session) => _outcomes[_calls++].future;
}

/// Gateway whose every outcome is chosen by the test.
///
/// Records what it was asked, so a test can assert the credential reached it
/// and that a renewal did *not* happen when it should not have.
class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.signInOutcome, this.renewOutcome});

  final AuthOutcome? signInOutcome;
  final AuthOutcome? renewOutcome;

  final List<String> codes = <String>[];
  int renewals = 0;

  @override
  Future<AuthOutcome> signIn(String accessCode) async {
    codes.add(accessCode);
    return signInOutcome ?? AuthGranted(_granted('granted-access-token'));
  }

  @override
  Future<AuthOutcome> renew(Session session) async {
    renewals++;
    return renewOutcome ?? AuthGranted(_granted('renewed-access-token'));
  }

  Session _granted(String accessToken) => Session(
    accessToken: accessToken,
    refreshToken: 'granted-refresh-token',
    expiresAt: DateTime.utc(2026, 8, 14, 13),
    refreshExpiresAt: DateTime.utc(2026, 8, 21),
    operatorId: 'operator-1',
    operatorName: 'Operator One',
  );
}
