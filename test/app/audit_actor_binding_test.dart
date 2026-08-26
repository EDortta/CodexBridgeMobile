import 'package:codex_bridge_mobile/app/audit_actor_binding.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:codex_bridge_mobile/features/auth/presentation/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure decision behind [auditActorBinding], both branches under a plain
/// unit test — the same shape `resolveDecisionRepository`'s test has.
void main() {
  final Session session = Session(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.utc(2026, 8, 26, 16),
    refreshExpiresAt: DateTime.utc(2026, 8, 27, 15),
    operatorId: 'op-42',
    operatorName: 'Esteban',
  );

  test('a signed-in session resolves to the server-resolved operator id', () {
    expect(resolveAuditActor(SignedIn(session)), 'op-42');
    // Renewing keeps the same held session — still the same actor.
    expect(resolveAuditActor(SignedIn(session, renewing: true)), 'op-42');
  });

  test('signed out, still loading, or absent resolves to null', () {
    expect(
      resolveAuditActor(
        const SignedOut(reason: SignedOutReason.neverSignedIn),
      ),
      isNull,
    );
    expect(resolveAuditActor(null), isNull);
  });
}
