import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format/relative_moment.dart';
import 'audit_event.dart';
import 'audit_trail_repository.dart';
import 'in_memory_audit_trail_repository.dart';

/// Who the current audit actor is — the signed-in operator's id, or null
/// when nobody is signed in.
///
/// Resolves to null by default: `core/` must not import a feature
/// (`docs/architecture/state-architecture.md`), so the real resolution —
/// reading the session — is wired in as an override by `lib/app/`
/// (`audit_actor_binding.dart`), exactly the shape `gatewayContextProvider`
/// already uses.
final Provider<String?> auditActorProvider = Provider<String?>(
  (Ref ref) => null,
);

/// The one audit store this process writes to and reads from. Not
/// `autoDispose`: the trail must outlive every screen that contributed to it.
final Provider<AuditTrailRepository> auditTrailRepositoryProvider =
    Provider<AuditTrailRepository>(
      (Ref ref) =>
          InMemoryAuditTrailRepository(clock: ref.watch(appClockProvider)),
    );

/// Every recorded event, newest first — what the read-only trail screen
/// (`features/audit/`) renders.
///
/// `autoDispose` alone is not what keeps this current: the shell's
/// `StatefulShellRoute.indexedStack` keeps every branch mounted, so the
/// Account branch's listener survives a destination switch and the provider
/// never disposes while events land elsewhere. [AuditRecorder] invalidates
/// this provider after every write instead (council 2026-08-26, the second
/// caller, round 1 — a trail screen showing yesterday's list contradicts
/// the issue).
final AutoDisposeFutureProvider<List<AuditEvent>> auditEventsProvider =
    FutureProvider.autoDispose<List<AuditEvent>>((Ref ref) async {
      return ref.watch(auditTrailRepositoryProvider).loadEvents();
    });

/// Read at each call site instead of [auditTrailRepositoryProvider] directly,
/// so every recording resolves the actor the same way and no operation can
/// fail because its audit write did.
final Provider<AuditRecorder> auditRecorderProvider = Provider<AuditRecorder>(
  (Ref ref) => AuditRecorder(
    ref.watch(auditTrailRepositoryProvider),
    // A function, not a captured value: the actor is whoever is signed in
    // when the event is recorded, not whoever was when this provider is
    // first built.
    () => ref.read(auditActorProvider),
    // A mounted trail screen sees the new event immediately — see
    // [auditEventsProvider] for why autoDispose cannot do this alone.
    () => ref.invalidate(auditEventsProvider),
  ),
);

/// Written in place of an actor when no session identifies one — a failed
/// precondition can fire before sign-in, and "we don't know who" is itself
/// a fact worth recording rather than a reason to drop the event.
const String unknownAuditActor = 'unknown';

class AuditRecorder {
  const AuditRecorder(this._repository, this._resolveActor, [this._onRecorded]);

  final AuditTrailRepository _repository;
  final String? Function() _resolveActor;

  /// Runs after a successful write — production wires it to invalidate
  /// [auditEventsProvider]. Optional so a bare unit test needs no stub.
  final void Function()? _onRecorded;

  /// Records one event; never throws.
  ///
  /// Swallowing here is a deliberate trade-off, not an accident: every call
  /// site sits inside an operation the operator is mid-way through, and a
  /// throwing audit write would turn "the operation succeeded" into an error
  /// screen about bookkeeping. With the in-memory store a failure cannot
  /// happen at all; when a real backend can refuse a write, whether the
  /// operation must then block (audit-before-act) is that integration's
  /// explicit design decision — flagged in `docs/issues/epic-14/RESUME.md`,
  /// not silently pre-decided here.
  Future<void> record({
    required AuditArea area,
    required String action,
    required String target,
    required AuditResult result,
    String? failureReason,
    Map<String, String> context = const <String, String>{},
  }) async {
    try {
      await _repository.record(
        actor: _resolveActor() ?? unknownAuditActor,
        area: area,
        action: action,
        target: target,
        result: result,
        failureReason: failureReason,
        context: context,
      );
      _onRecorded?.call();
    } on Exception {
      // See the method's doc comment.
    }
  }
}
