import 'dart:convert';

import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// The session's two promises, pinned without a device and without waiting for
/// a clock: what a lifecycle means at a given instant, and what a stored value
/// is allowed to decode into.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 14, 12);

  Session sessionWith({
    required Duration expiresIn,
    Duration refreshExpiresIn = const Duration(days: 7),
  }) {
    return Session(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: now.add(expiresIn),
      refreshExpiresAt: now.add(refreshExpiresIn),
      operatorId: 'operator-1',
      operatorName: 'Operator One',
    );
  }

  group('lifecycle', () {
    test('a session far from expiry is active', () {
      final Session session = sessionWith(expiresIn: const Duration(hours: 1));

      expect(session.lifecycleAt(now), SessionLifecycle.active);
      expect(session.isExpiredAt(now), isFalse);
    });

    test('renewal is due before expiry, not at it', () {
      // The window exists so a request is never sent with a token that expires
      // while it is in flight. If renewal only began at expiry, every renewal
      // would race the thing it is renewing.
      final Session session = sessionWith(
        expiresIn: Session.renewalLeadTime - const Duration(seconds: 1),
      );

      expect(session.isExpiredAt(now), isFalse);
      expect(session.lifecycleAt(now), SessionLifecycle.renewalDue);
    });

    test('an expired access token with an open refresh window is renewable', () {
      final Session session = sessionWith(expiresIn: -const Duration(hours: 1));

      expect(session.isExpiredAt(now), isTrue);
      expect(session.lifecycleAt(now), SessionLifecycle.renewalDue);
    });

    test('an expired session with a closed refresh window is expired', () {
      final Session session = sessionWith(
        expiresIn: -const Duration(days: 8),
        refreshExpiresIn: -const Duration(days: 1),
      );

      expect(session.lifecycleAt(now), SessionLifecycle.expired);
      expect(session.isRenewableAt(now), isFalse);
    });

    test(
      'a still-valid token whose refresh window closed stays active, not expired',
      () {
        // Renewal is impossible, but the token works. Reporting this as expired
        // would sign the operator out of a session that is still good.
        final Session session = sessionWith(
          expiresIn: const Duration(hours: 1),
          refreshExpiresIn: -const Duration(minutes: 1),
        );

        expect(session.lifecycleAt(now), SessionLifecycle.active);
      },
    );

    test('expiry is inclusive: the instant of expiry is already expired', () {
      final Session session = sessionWith(expiresIn: Duration.zero);

      expect(session.isExpiredAt(now), isTrue);
    });
  });

  group('encoding', () {
    test('a session survives a round trip through storage', () {
      final Session original = sessionWith(expiresIn: const Duration(hours: 1));

      final Session? restored = Session.tryDecode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.operatorId, original.operatorId);
      expect(restored.operatorName, original.operatorName);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.refreshExpiresAt, original.refreshExpiresAt);
    });

    test('an expiry written in local time reads back as the same instant', () {
      // A device that changes time zone between two launches must not read a
      // different expiry than the one it wrote.
      final Session local = Session(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2026, 8, 14, 13).toLocal(),
        refreshExpiresAt: DateTime.utc(2026, 8, 21).toLocal(),
        operatorId: 'operator-1',
        operatorName: 'Operator One',
      );

      final Session? restored = Session.tryDecode(local.encode());

      expect(restored!.expiresAt.isAtSameMomentAs(local.expiresAt), isTrue);
    });

    test('a value that is not JSON decodes to null, it does not throw', () {
      expect(Session.tryDecode('not json at all'), isNull);
      expect(Session.tryDecode(''), isNull);
      expect(Session.tryDecode('[1, 2, 3]'), isNull);
    });

    test('every required field is required, one at a time', () {
      // The failure this prevents: a partially-decoded session passing as a
      // Session, so the app believes it is signed in while holding an empty
      // token and every request fails with no path back
      // (`design-standards.md` §6).
      final Map<String, Object?> complete =
          jsonDecode(sessionWith(expiresIn: const Duration(hours: 1)).encode())
              as Map<String, Object?>;

      for (final String field in complete.keys) {
        final Map<String, Object?> missing = Map<String, Object?>.of(complete)
          ..remove(field);

        expect(
          Session.tryDecode(jsonEncode(missing)),
          isNull,
          reason: 'a session without "$field" decoded into a valid-looking one',
        );
      }
    });

    test('an empty token is not a token', () {
      final Map<String, Object?> blanked =
          jsonDecode(sessionWith(expiresIn: const Duration(hours: 1)).encode())
                  as Map<String, Object?>
              ..['accessToken'] = '';

      expect(Session.tryDecode(jsonEncode(blanked)), isNull);
    });

    test('an unparseable instant is refused, not defaulted', () {
      final Map<String, Object?> broken =
          jsonDecode(sessionWith(expiresIn: const Duration(hours: 1)).encode())
                  as Map<String, Object?>
              ..['expiresAt'] = 'yesterday';

      expect(Session.tryDecode(jsonEncode(broken)), isNull);
    });
  });

  test('toString redacts both tokens', () {
    // toString is what a crash report, a print and a failing expect all reach
    // for. None of them is a place for a credential.
    final Session session = sessionWith(expiresIn: const Duration(hours: 1));

    final String rendered = session.toString();

    expect(rendered, isNot(contains(session.accessToken)));
    expect(rendered, isNot(contains(session.refreshToken)));
    expect(rendered, contains(session.operatorId));
  });
}
