import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_event.dart';
import '../../../core/audit/audit_providers.dart';
import '../../../core/gateway/gateway_context.dart';
import '../../../core/gateway/gateway_context_provider.dart';
import '../data/http_live_session_repository.dart';
import '../domain/live_session.dart';
import '../domain/live_session_explanation.dart';
import '../domain/live_session_log_entry.dart';
import '../domain/live_session_repository.dart';

class RemoteSessionsState {
  const RemoteSessionsState({
    this.sessions = const <LiveSession>[],
    this.information,
    this.error,
    this.pending = const <String>{},
  });

  final List<LiveSession> sessions;
  final String? information;
  final String? error;
  final Set<String> pending;
}

final Provider<LiveSessionRepository> liveSessionRepositoryProvider =
    Provider<LiveSessionRepository>(
      (Ref ref) => const HttpLiveSessionRepository(),
    );

final AutoDisposeFutureProviderFamily<LiveSession, String>
liveSessionDetailProvider =
    FutureProvider.autoDispose.family<LiveSession, String>((
      Ref ref,
      String sessionId,
    ) async {
      final GatewayContext? context = await ref.watch(gatewayContextProvider.future);
      if (context == null) {
        throw const LiveSessionRepositoryException(
          'Select a server and sign in to inspect sessions.',
        );
      }
      return ref
          .read(liveSessionRepositoryProvider)
          .loadSessionDetail(
            server: context.server,
            accessToken: context.accessToken,
            sessionId: sessionId,
          );
    });

final AutoDisposeFutureProviderFamily<List<LiveSessionLogEntry>, String>
liveSessionLogsProvider =
    FutureProvider.autoDispose.family<List<LiveSessionLogEntry>, String>((
      Ref ref,
      String sessionId,
    ) async {
      final GatewayContext? context = await ref.watch(gatewayContextProvider.future);
      if (context == null) {
        throw const LiveSessionRepositoryException(
          'Select a server and sign in to inspect session logs.',
        );
      }
      return ref
          .read(liveSessionRepositoryProvider)
          .loadSessionLogs(
            server: context.server,
            accessToken: context.accessToken,
            sessionId: sessionId,
          );
    });

final AutoDisposeFutureProviderFamily<LiveSessionErrorExplanation, String>
liveSessionErrorExplanationProvider =
    FutureProvider.autoDispose.family<LiveSessionErrorExplanation, String>((
      Ref ref,
      String sessionId,
    ) async {
      final GatewayContext? context = await ref.watch(gatewayContextProvider.future);
      if (context == null) {
        throw const LiveSessionRepositoryException(
          'Select a server and sign in to explain this session.',
        );
      }
      return ref
          .read(liveSessionRepositoryProvider)
          .explainError(
            server: context.server,
            accessToken: context.accessToken,
            sessionId: sessionId,
          );
    });

final AsyncNotifierProvider<RemoteSessionsController, RemoteSessionsState>
remoteSessionsProvider =
    AsyncNotifierProvider<RemoteSessionsController, RemoteSessionsState>(
      RemoteSessionsController.new,
    );

class RemoteSessionsController extends AsyncNotifier<RemoteSessionsState> {
  @override
  Future<RemoteSessionsState> build() async {
    final GatewayContext? context = await ref.watch(gatewayContextProvider.future);
    if (context == null) {
      return const RemoteSessionsState(
        information: 'Select a server and sign in to control live sessions.',
      );
    }
    try {
      final List<LiveSession> sessions = await ref
          .read(liveSessionRepositoryProvider)
          .loadSessions(server: context.server, accessToken: context.accessToken);
      return RemoteSessionsState(
        sessions: sessions,
        information: sessions.isEmpty
            ? 'No sessions are visible from this device.'
            : null,
      );
    } on LiveSessionRepositoryException catch (error) {
      return RemoteSessionsState(error: error.message);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<RemoteSessionsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  Future<void> control(
    String sessionId,
    LiveSessionControlAction action,
  ) async {
    final AuditRecorder audit = ref.read(auditRecorderProvider);
    final RemoteSessionsState current =
        state.valueOrNull ?? const RemoteSessionsState();
    if (current.pending.contains(sessionId)) {
      // Already in flight for this session. The UI's own busy/disabled state
      // is meant to stop a second tap from reaching here at all, but that
      // guard used to be reliable only because the old revision lookup was
      // synchronous — `pending` was set before any `await`, closing the
      // window to under one microtask. Falling back to `loadSessionDetail`
      // for a session outside the cached list (below) reopened that window
      // to a full HTTP round trip, and a second tap landing inside it fired
      // a second, duplicate submission — for a destructive action too
      // (council 2026-08-18, "the adversarial user", reproduced live).
      // Setting `pending` synchronously, first, below, is the actual fix;
      // this check is the backstop for whatever still slips past it.
      //
      // Not an audit event (#46): nothing was attempted or cancelled here —
      // the suppressed tap is a duplicate of an operation already in flight,
      // and that first operation records its own outcome below.
      return;
    }
    state = AsyncData<RemoteSessionsState>(
      RemoteSessionsState(
        sessions: current.sessions,
        information: current.information,
        error: current.error,
        pending: <String>{...current.pending, sessionId},
      ),
    );
    final GatewayContext? context = await ref.read(gatewayContextProvider.future);
    if (context == null) {
      state = AsyncData<RemoteSessionsState>(
        RemoteSessionsState(
          information: 'Select a server and sign in to control live sessions.',
        ),
      );
      // A precondition stopped the action before it could be sent — a
      // failure the trail keeps, like any other (#46). Recorded after the
      // state write, like every record in this method: the audit write must
      // never sit inside the window where `pending` disables the button —
      // free with the in-memory store, a network round trip once an HTTP
      // audit backend exists (council 2026-08-26, the second caller, r1).
      await audit.record(
        area: AuditArea.liveSession,
        action: action.name,
        target: sessionId,
        result: AuditResult.failure,
        failureReason: 'No server selected or no signed-in session.',
      );
      return;
    }
    final LiveSessionRepository repository = ref.read(liveSessionRepositoryProvider);
    final int revision;
    try {
      revision = await _revisionFor(repository, context, current, sessionId);
    } on Exception catch (error) {
      // `on Exception`, not only the repository's own type: a malformed 200
      // payload surfaces as `FormatException` from `LiveSession.fromJson`,
      // and letting it escape here would leave `pending` stuck and the
      // failure unrecorded (council 2026-08-26, the adversarial user, r1).
      final String message = _controlFailureMessage(error);
      state = AsyncData<RemoteSessionsState>(
        RemoteSessionsState(
          sessions: current.sessions,
          information: current.information,
          error: message,
          pending: current.pending,
        ),
      );
      await audit.record(
        area: AuditArea.liveSession,
        action: action.name,
        target: sessionId,
        result: AuditResult.failure,
        failureReason: message,
      );
      return;
    }
    try {
      final LiveSession updated = await repository.controlSession(
        server: context.server,
        accessToken: context.accessToken,
        sessionId: sessionId,
        revision: revision,
        action: action,
      );
      state = AsyncData<RemoteSessionsState>(
        RemoteSessionsState(
          sessions: current.sessions
              .map((LiveSession item) => item.id == sessionId ? updated : item)
              .toList(growable: false),
          information: current.information,
          error: null,
          pending: current.pending.where((String id) => id != sessionId).toSet(),
        ),
      );
      // After the state write — see the precondition branch above for why.
      await audit.record(
        area: AuditArea.liveSession,
        action: action.name,
        target: sessionId,
        result: AuditResult.success,
      );
    } on Exception catch (error) {
      // `on Exception` for the same reason `_revisionFor`'s catch is: a
      // malformed success payload must still clear `pending` and still be
      // a recorded failure (council 2026-08-26, the adversarial user, r1).
      final String message = _controlFailureMessage(error);
      state = AsyncData<RemoteSessionsState>(
        RemoteSessionsState(
          sessions: current.sessions,
          information: current.information,
          error: message,
          pending: current.pending.where((String id) => id != sessionId).toSet(),
        ),
      );
      await audit.record(
        area: AuditArea.liveSession,
        action: action.name,
        target: sessionId,
        result: AuditResult.failure,
        failureReason: message,
      );
    }
  }
}

/// The operator-facing message for a failed control action.
///
/// [LiveSessionRepositoryException] already carries one; anything else is a
/// code-level failure (a malformed payload, most likely) whose `toString`
/// is the honest thing to show and record rather than a fabricated
/// explanation.
String _controlFailureMessage(Exception error) => switch (error) {
  LiveSessionRepositoryException(:final String message) => message,
  _ => '$error',
};

/// The revision to send with a control action's `If-Match`.
///
/// Prefers the cached list entry, but a session absent from it — a cold
/// navigation straight into the detail screen before [remoteSessionsProvider]
/// ever loaded, or one outside `loadSessions()`'s own scope — is fetched
/// directly instead of left to an unguarded list lookup that throws
/// (council 2026-08-18, "the sweep skeptic" / "the second caller" /
/// "the adversarial user": four independent lenses reached the same crash
/// through this one call site). Fetching fresh also means the revision sent
/// is never a stale copy of one the detail screen's own, independently
/// loaded [LiveSession] has already moved past.
Future<int> _revisionFor(
  LiveSessionRepository repository,
  GatewayContext context,
  RemoteSessionsState current,
  String sessionId,
) async {
  final Iterable<LiveSession> cached = current.sessions.where(
    (LiveSession item) => item.id == sessionId,
  );
  if (cached.isNotEmpty) {
    return cached.first.revision;
  }
  final LiveSession detail = await repository.loadSessionDetail(
    server: context.server,
    accessToken: context.accessToken,
    sessionId: sessionId,
  );
  return detail.revision;
}

/// Sends [action] for [sessionId], confirming first when [action] is
/// destructive.
///
/// Both the sessions list and the session detail screen call this instead of
/// [RemoteSessionsController.control] directly, so a stop or a restart cannot
/// fire on the first tap on either surface — and a future third surface gets
/// the same guard by construction rather than by remembering to add it.
Future<void> runSessionControlAction(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
  LiveSessionControlAction action,
) async {
  // Both captured before the dialog's await: the calling widget can be
  // disposed while the dialog is up (a redirect, a programmatic pop), and
  // `ref.read` on a disposed consumer throws — losing the cancelled event
  // (council 2026-08-26, the second caller, round 1) or, one line further
  // down, silently dropping a *confirmed* destructive action and its audit
  // event with it (same lens, round 2). The captured objects stay valid:
  // both come from non-autoDispose providers whose own `Ref` outlives any
  // widget.
  final AuditRecorder audit = ref.read(auditRecorderProvider);
  final RemoteSessionsController controller = ref.read(
    remoteSessionsProvider.notifier,
  );
  if (action.isDestructive) {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(action.confirmTitle),
        content: Text(action.confirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      // The operator backed out of a destructive action at its confirmation
      // — recorded, not dropped (#46: "failed and cancelled operations are
      // included"). Pause/resume never reach here: with no confirmation
      // step there is no cancel to record.
      await audit.record(
        area: AuditArea.liveSession,
        action: action.name,
        target: sessionId,
        result: AuditResult.cancelled,
      );
      return;
    }
  }
  await controller.control(sessionId, action);
}
