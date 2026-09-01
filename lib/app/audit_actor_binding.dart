import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audit/audit_providers.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/auth_state.dart';

/// The real [auditActorProvider]: the signed-in operator's id, composed here
/// because `lib/app/` is the one layer allowed to import `auth`
/// (`state-architecture.md`) — same shape as [gatewayContextBinding].
final Override auditActorBinding = auditActorProvider.overrideWith(
  (Ref ref) => resolveAuditActor(ref.watch(sessionProvider).valueOrNull),
);

/// The decision behind [auditActorBinding], pulled out so both branches run
/// under a plain unit test (`design-standards.md` §1), the same way
/// `resolveDecisionRepository` is.
///
/// [Session.operatorId] rather than `operatorName`: the id is the
/// server-resolved identity (`session.dart` — never client-chosen), while
/// the display name is presentation. Null — not signed in, or the session
/// state still loading — becomes `unknown` at recording time
/// (`AuditRecorder`), not here, so the provider's contract stays "who is
/// signed in", nothing more.
String? resolveAuditActor(AuthState? authState) {
  if (authState case SignedIn(:final session)) {
    return session.operatorId;
  }
  return null;
}
