import 'package:codex_bridge_mobile/features/auth/data/secure_session_store.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

/// "Sensitive values are protected by platform storage" and "sign-out clears
/// local session state" are two of issue #22's acceptance criteria. Both are
/// decisions this class makes, so both are pinned here — the platform call
/// underneath is a three-line delegating adapter with no decision in it.
void main() {
  final Session session = Session(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.utc(2026, 8, 14, 13),
    refreshExpiresAt: DateTime.utc(2026, 8, 21),
    operatorId: 'operator-1',
    operatorName: 'Operator One',
  );

  test('a written session is read back through the secure store', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    final SecureSessionStore store = SecureSessionStore(storage);

    await store.writeSession(session);
    final Session? restored = await store.readSession();

    expect(restored, isNotNull);
    expect(restored!.accessToken, session.accessToken);
    expect(restored.operatorId, session.operatorId);
  });

  test('the session goes to secure storage, under its own key', () async {
    // The key is namespaced so it cannot collide with the selected server
    // (#21), and the value must be in the keystore-backed store rather than
    // anywhere a backup could read.
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();

    await SecureSessionStore(storage).writeSession(session);

    expect(storage.entries.keys, <String>[SecureSessionStore.sessionKey]);
  });

  test('no session stored reads as null', () async {
    final SecureSessionStore store = SecureSessionStore(
      InMemorySecureKeyValueStore(),
    );

    expect(await store.readSession(), isNull);
  });

  test('a stored value that no longer decodes reads as signed out', () async {
    // The failure this prevents: a truncated or older-format value throwing on
    // launch, so the account screen cannot open at all. Unreadable local state
    // means signed out, which the operator can recover from
    // (`design-standards.md` §6).
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore(
      <String, String>{SecureSessionStore.sessionKey: '{"accessToken":'},
    );

    expect(await SecureSessionStore(storage).readSession(), isNull);
  });

  test('a keystore that cannot be read reads as signed out', () async {
    // `SessionStore.readSession` promises null for local state it cannot make
    // sense of. An implementation that throws instead is not that type
    // (`design-standards.md` §6) — and the caller is `build()`, so the throw
    // arrives as an account screen that cannot open on any launch.
    expect(
      await SecureSessionStore(
        const UnavailableSecureKeyValueStore(),
      ).readSession(),
      isNull,
    );
  });

  test('a keystore that refuses a write does not report the session stored', () async {
    // The opposite direction, deliberately: there is no safe value to invent
    // for "the session was not stored", so this one throws and the controller
    // renders it.
    final SecureSessionStore store = SecureSessionStore(
      WriteRefusingSecureKeyValueStore(),
    );

    await expectLater(store.writeSession(session), throwsA(anything));
  });

  test('clearSession removes the value, not just its contents', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    final SecureSessionStore store = SecureSessionStore(storage);
    await store.writeSession(session);

    await store.clearSession();

    expect(
      storage.entries,
      isEmpty,
      reason:
          'sign-out left the entry behind; a blanked value is still a value '
          'an attacker with the device can inspect',
    );
    expect(await store.readSession(), isNull);
  });

  test('clearing when nothing is stored succeeds', () async {
    // A sign-out must never fail for want of something to remove, or the app
    // would be unable to leave a state it is already in.
    final SecureSessionStore store = SecureSessionStore(
      InMemorySecureKeyValueStore(),
    );

    await expectLater(store.clearSession(), completes);
  });

  test(
    'a session written after a refused removal survives the next read',
    () async {
      // The council round-2 pending-removal finding: `clearSession` marks
      // the entry pending-removal when the platform delete is refused, and
      // nothing but a later *successful* `clearSession` ever retired that
      // marker. A fresh `writeSession` after the refusal — an ordinary
      // sign-in-again, not a race — left the marker standing, so the session
      // just written read back as null on every later launch.
      final DeleteRefusingSecureKeyValueStore storage =
          DeleteRefusingSecureKeyValueStore();
      final SecureSessionStore store = SecureSessionStore(storage);
      await store.writeSession(session);
      await expectLater(store.clearSession(), throwsA(anything));

      await store.writeSession(session);

      expect(
        await store.readSession(),
        isNotNull,
        reason:
            'the fresh session was persisted but a stale pending-removal '
            'marker from the refused removal hid it from every later read',
      );
    },
  );

  test(
    'a marker cleared on write does not depend on a delete succeeding',
    () async {
      // Same finding, aimed at the mechanism rather than the outcome: on a
      // keystore that refuses every delete, a marker retired via `delete`
      // would fail exactly the way the original removal did. Clearing it
      // must not need the one operation this keystore has already refused.
      final DeleteRefusingSecureKeyValueStore storage =
          DeleteRefusingSecureKeyValueStore();
      final SecureSessionStore store = SecureSessionStore(storage);
      await store.writeSession(session);
      await expectLater(store.clearSession(), throwsA(anything));

      await store.writeSession(session);

      expect(
        storage.entries['codex_bridge.session.pending_removal'],
        isNot('true'),
        reason: 'the marker was never actually cleared, only left unread',
      );
    },
  );

  test(
    'writing a session for the first time does not grow a marker key',
    () async {
      // The fix must not run unconditionally: a device that never hit a
      // refused removal must never see this key appear at all.
      final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();

      await SecureSessionStore(storage).writeSession(session);

      expect(storage.entries.keys, <String>[SecureSessionStore.sessionKey]);
    },
  );

  test(
    'a successful retry clears the marker even when the marker\'s own '
    'delete is refused the first time',
    () async {
      // The realistic recovery case: the session delete succeeds on retry,
      // but a per-key-refusing keystore would refuse the *marker's* delete
      // on its own first attempt — a delete-based cleanup would still lose
      // the race even though the removal that mattered fully worked.
      final DeleteRefusingOnceSecureKeyValueStore storage =
          DeleteRefusingOnceSecureKeyValueStore();
      final SecureSessionStore store = SecureSessionStore(storage);
      await store.writeSession(session);
      await expectLater(store.clearSession(), throwsA(anything));

      await store.clearSession();
      await store.writeSession(session);

      expect(
        await store.readSession(),
        isNotNull,
        reason:
            'the retry actually removed the session and the marker should '
            'have gone with it',
      );
    },
  );
}
