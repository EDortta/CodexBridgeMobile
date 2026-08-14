import 'package:codex_bridge_mobile/features/auth/data/mock_auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// The interim gateway is not an authenticator, and this file does not pretend
/// it is. What it pins is the part that stays true once the real Codex Bridge
/// endpoints replace it: the two windows a granted session carries, the promise
/// that neither method throws, and the refusal to renew a session whose refresh
/// window has closed.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 14, 12);
  final MockAuthGateway gateway = MockAuthGateway(() => now);

  test('a blank access code is refused, and named', () async {
    for (final String blank in <String>['', '   ', '\n']) {
      final AuthOutcome outcome = await gateway.signIn(blank);

      expect(outcome, isA<AuthDenied>());
      expect(
        (outcome as AuthDenied).reason,
        AuthFailure.missingCredential,
        reason: 'a blank code read as a wrong code, which is a different fix',
      );
    }
  });

  test('a granted session carries both windows, opened from now', () async {
    final AuthOutcome outcome = await gateway.signIn('an-access-code');

    final Session session = (outcome as AuthGranted).session;
    expect(session.expiresAt, now.add(MockAuthGateway.accessLifetime));
    expect(session.refreshExpiresAt, now.add(MockAuthGateway.refreshLifetime));
    expect(session.lifecycleAt(now), SessionLifecycle.active);
  });

  test('the access window is shorter than the refresh window', () async {
    // A renewal is only meaningful while the outer window outlives the inner
    // one; inverted, every session would be unrenewable from the moment it is
    // issued.
    expect(
      MockAuthGateway.accessLifetime,
      lessThan(MockAuthGateway.refreshLifetime),
    );
  });

  test('a renewal moves the access window and leaves the refresh window', () async {
    // A refresh window that slid forward on every renewal would never close,
    // and a lost device would hold a session indefinitely.
    final Session issued =
        ((await gateway.signIn('code')) as AuthGranted).session;
    final DateTime later = now.add(const Duration(hours: 2));

    final AuthOutcome outcome = await MockAuthGateway(() => later).renew(issued);

    final Session renewed = (outcome as AuthGranted).session;
    expect(renewed.expiresAt, later.add(MockAuthGateway.accessLifetime));
    expect(renewed.refreshExpiresAt, issued.refreshExpiresAt);
    expect(renewed.accessToken, isNot(issued.accessToken));
  });

  test('a session past its refresh window is not renewed', () async {
    final Session issued =
        ((await gateway.signIn('code')) as AuthGranted).session;
    final DateTime tooLate = now
        .add(MockAuthGateway.refreshLifetime)
        .add(const Duration(seconds: 1));

    final AuthOutcome outcome = await MockAuthGateway(
      () => tooLate,
    ).renew(issued);

    expect(
      (outcome as AuthDenied).reason,
      AuthFailure.sessionNoLongerRenewable,
    );
  });

  test('every failure carries a message a screen can render', () {
    for (final AuthFailure failure in AuthFailure.values) {
      expect(failure.message, isNotEmpty);
    }
  });
}
