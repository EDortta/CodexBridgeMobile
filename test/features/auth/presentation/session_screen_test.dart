import 'package:codex_bridge_mobile/app/app.dart';
import 'package:codex_bridge_mobile/app/app_router.dart';
import 'package:codex_bridge_mobile/core/navigation/app_routes.dart';
import 'package:codex_bridge_mobile/core/storage/secure_storage_providers.dart';
import 'package:codex_bridge_mobile/features/auth/data/secure_session_store.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_providers.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

/// The operator-facing half of issue #22: the screen reached at
/// `/account/session`, what it says when a session expired, and what it never
/// shows.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 14, 12);

  Session sessionWith({
    required Duration expiresIn,
    Duration refreshExpiresIn = const Duration(days: 7),
  }) {
    return Session(
      accessToken: 'ACCESS-TOKEN-MARKER',
      refreshToken: 'REFRESH-TOKEN-MARKER',
      expiresAt: now.add(expiresIn),
      refreshExpiresAt: now.add(refreshExpiresIn),
      operatorId: 'operator-1',
      operatorName: 'Operator One',
    );
  }

  Future<InMemorySecureKeyValueStore> pumpSession(
    WidgetTester tester, {
    Session? stored,
    InMemorySecureKeyValueStore Function(Map<String, String> seed)? keystore,
  }) async {
    final Map<String, String> seed = stored == null
        ? <String, String>{}
        : <String, String>{SecureSessionStore.sessionKey: stored.encode()};
    final InMemorySecureKeyValueStore storage = keystore == null
        ? InMemorySecureKeyValueStore(seed)
        : keystore(seed);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureKeyValueStoreProvider.overrideWithValue(storage),
          sessionClockProvider.overrideWithValue(() => now),
        ],
        child: CodexBridgeMobileApp(
          router: createAppRouter(initialLocation: AppRoutes.session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return storage;
  }

  testWidgets('the session route resolves, with the shell intact', (
    WidgetTester tester,
  ) async {
    await pumpSession(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Session'),
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a device that never signed in is invited to sign in', (
    WidgetTester tester,
  ) async {
    await pumpSession(tester);

    expect(
      find.text(SignedOutReason.neverSignedIn.message),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('an expired session says so and offers the way back', (
    WidgetTester tester,
  ) async {
    // The acceptance criterion is that an expired session "recovers through a
    // clear flow". Clear means the screen states what happened; a flow means
    // the recovery is on the same screen, not a dead end.
    await pumpSession(
      tester,
      stored: sessionWith(
        expiresIn: -const Duration(days: 8),
        refreshExpiresIn: -const Duration(days: 1),
      ),
    );

    expect(
      find.text(SignedOutReason.sessionExpired.message),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('signing in from the expired screen restores a session', (
    WidgetTester tester,
  ) async {
    final InMemorySecureKeyValueStore storage = await pumpSession(
      tester,
      stored: sessionWith(
        expiresIn: -const Duration(days: 8),
        refreshExpiresIn: -const Duration(days: 1),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'an-operator');
    await tester.enterText(find.byType(TextField).at(1), 'an-access-code');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);
    expect(storage.entries[SecureSessionStore.sessionKey], isNotNull);
  });

  testWidgets('a signed-in device shows who and until when, never the token', (
    WidgetTester tester,
  ) async {
    final Session session = sessionWith(expiresIn: const Duration(hours: 1));
    await pumpSession(tester, stored: session);

    expect(find.text(session.operatorName), findsOneWidget);
    expect(find.text(session.operatorId), findsOneWidget);
    expect(find.textContaining('2026-08-14 13:00 UTC'), findsOneWidget);

    for (final String secret in <String>[
      session.accessToken,
      session.refreshToken,
    ]) {
      expect(
        find.textContaining(secret),
        findsNothing,
        reason: 'a credential reached the screen; nothing renders a token',
      );
    }
  });

  testWidgets('the password is masked while it is typed', (
    WidgetTester tester,
  ) async {
    await pumpSession(tester);

    final TextField field = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );

    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(
      field.enableSuggestions,
      isFalse,
      reason:
          'a credential offered to the keyboard suggestion store leaves this '
          'app entirely',
    );
  });

  testWidgets('signing out clears the keystore and returns to sign-in', (
    WidgetTester tester,
  ) async {
    final InMemorySecureKeyValueStore storage = await pumpSession(
      tester,
      stored: sessionWith(expiresIn: const Duration(hours: 1)),
    );
    expect(storage.entries[SecureSessionStore.sessionKey], isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text(SignedOutReason.signedOut.message), findsOneWidget);
    expect(
      storage.entries,
      isEmpty,
      reason: 'the screen returned to sign-in while the token stayed on disk',
    );
  });

  testWidgets('a sign-out the device refuses is on screen, with a way to retry', (
    WidgetTester tester,
  ) async {
    // The screen calls the controller and renders provider state, so a failure
    // that escapes the controller reaches no widget at all: the tap does
    // nothing, silently, and the operator is told the device is clean when it
    // is not.
    final InMemorySecureKeyValueStore storage = await pumpSession(
      tester,
      stored: sessionWith(expiresIn: const Duration(hours: 1)),
      keystore: DeleteRefusingSecureKeyValueStore.new,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text(SignedOut.sessionMayRemainMessage), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Remove from this device'),
      findsOneWidget,
      reason: 'a warning the operator cannot act on is a dead end',
    );
    expect(storage.entries[SecureSessionStore.sessionKey], isNotNull);
  });

  testWidgets('a sign-in the device cannot store leaves the form usable', (
    WidgetTester tester,
  ) async {
    await pumpSession(tester, keystore: WriteRefusingSecureKeyValueStore.new);

    await tester.enterText(find.byType(TextField).at(0), 'an-operator');
    await tester.enterText(find.byType(TextField).at(1), 'an-access-code');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text(SignedOutReason.storageUnavailable.message), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      ).onPressed,
      isNotNull,
      reason:
          'the button stayed disabled behind a spinner that never stops, and '
          'nothing on screen said why',
    );

    // The password is a credential, cleared the moment it is handed to the
    // gateway. The username is not a secret, and is left in place so the
    // operator can retry a mistyped password without retyping who they are.
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'an-operator',
      reason: 'the username is not a credential and survives a failed sign-in',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      isEmpty,
      reason: 'the password is cleared as soon as it reaches the gateway',
    );
  });

  testWidgets('the Account screen reaches the session screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureKeyValueStoreProvider.overrideWithValue(
            InMemorySecureKeyValueStore(),
          ),
          sessionClockProvider.overrideWithValue(() => now),
        ],
        child: CodexBridgeMobileApp(
          router: createAppRouter(initialLocation: AppRoutes.account),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in, renew, or sign out'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Session'),
      ),
      findsOneWidget,
    );
  });
}
