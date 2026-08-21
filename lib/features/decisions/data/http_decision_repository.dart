import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/gateway/gateway_context.dart';
import '../domain/decision.dart';
import '../domain/decision_audit_event.dart';
import '../domain/decision_repository.dart';
import '../domain/decision_risk.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';

/// Talks to the real Codex Bridge decisions endpoints
/// (`gateway/app/api/routes/decisions.py`, `docs/api/codex-bridge.openapi.yaml`
/// "decisions" section): list, detail, and the approve/reject/request-revision
/// resolution actions.
///
/// Structured like [HttpAuthGateway] (a plain [HttpClient] per call, every
/// connect/request/response step bounded by [timeout], certificate
/// verification never disabled) and [HttpLiveSessionRepository] (revision-based
/// `If-Match` optimistic concurrency, `SocketException`/`HandshakeException`
/// mapped to one client-facing exception type).
///
/// ## Why every resolve call reads before it writes
///
/// [DecisionRepository.approve]/[reject]/[requestRevision] carry no revision
/// parameter — unlike `LiveSessionRepository.controlSession`, which takes one
/// explicitly because `LiveSession` itself caches a `revision` field the UI
/// can pass back. [Decision] has no such field: adding one would be a domain
/// contract change reaching `decision_providers.dart`,
/// `decision_detail_screen.dart` and every existing decisions test, for a
/// value only this class needs. So each resolve call fetches the decision's
/// current revision first ([_revisionOf]), then sends it back as `If-Match`
/// on the write — the same two-network-call shape [HttpAuthGateway.signIn]
/// already uses (post the grant, then resolve `/auth/me`) rather than trust a
/// value the caller never had a chance to go stale on its own. A revision
/// that *does* go stale between these two calls — another operator resolved
/// the same decision in between — surfaces as [DecisionConflictException],
/// never silently retried.
///
/// ## Why `approve` always sends `confirm: true`
///
/// Every decision this backend serves today is `sensitive`
/// (`gateway/app/api/routes/decisions.py` module docstring), and the gateway
/// refuses to approve a sensitive decision without an explicit `confirm: true`
/// in the body — proof the operator meant to approve it, not just that the
/// client saw the current revision. Tapping "Approve" in
/// `DecisionDetailScreen` already is that deliberate act (a critical decision
/// additionally makes the operator check an acknowledgement box first), so
/// this class sends `confirm: true` on every approval rather than add a
/// parameter [DecisionRepository.approve] has no other use for today.
///
/// ## Why `discuss` always throws
///
/// `gateway/app/api/routes/decisions.py` exposes no discussion/comment
/// endpoint — there is nothing to send a comment to. Failing closed with a
/// clear message beats silently discarding the operator's comment or
/// fabricating a discussion entry that was never sent anywhere.
class HttpDecisionRepository implements DecisionRepository {
  const HttpDecisionRepository(
    this._resolveContext, {
    this.timeout = const Duration(seconds: 10),
  });

  /// Resolves the server and access token to call, or `null` when no server
  /// is selected or no session is signed in. A callable, like
  /// [HttpAuthGateway]'s `resolveServer` — `data/` in one feature must not
  /// import another feature's `presentation/` layer
  /// (`docs/architecture/state-architecture.md`), so the composition that
  /// knows both the selected server and the session lives in `lib/app/`
  /// (`decision_repository_binding.dart`).
  final Future<GatewayContext?> Function() _resolveContext;

  /// Applied to the connection, to each request and to reading each body —
  /// the same discipline [HttpAuthGateway] applies to its own calls, for the
  /// same reason: a server that accepts a socket and stalls must not hang the
  /// Decision Center screen.
  final Duration timeout;

  static const String _basePath = '/api/v1/decisions';

  @override
  Future<List<Decision>> loadDecisions() async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _get(context, _basePath);
    if (response.statusCode != HttpStatus.ok) {
      throw DecisionRepositoryException(
        _messageOf(response.body, fallback: 'Unable to load decisions.'),
      );
    }
    final Object? items = response.body['items'];
    if (items is! List<Object?>) {
      throw const DecisionRepositoryException(
        'The server answered without a decisions list.',
      );
    }
    return items
        .whereType<Map<String, Object?>>()
        .map(_decisionFromJson)
        .toList(growable: false);
  }

  @override
  Future<Decision> loadDecision(String decisionId) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _get(
      context,
      '$_basePath/$decisionId',
    );
    if (response.statusCode == HttpStatus.notFound) {
      throw DecisionNotFoundException(decisionId);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DecisionRepositoryException(
        _messageOf(response.body, fallback: 'Unable to load this decision.'),
      );
    }
    return _decisionFromJson(response.body);
  }

  @override
  Future<Decision> approve(String decisionId, {String? comment}) {
    final String? trimmed = comment?.trim();
    return _resolve(
      decisionId,
      segment: 'approve',
      body: <String, Object?>{
        if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
        'confirm': true,
      },
    );
  }

  @override
  Future<Decision> reject(
    String decisionId, {
    required String justification,
  }) async {
    if (justification.trim().isEmpty) {
      throw ArgumentError.value(
        justification,
        'justification',
        'A rejection requires a justification.',
      );
    }
    return _resolve(
      decisionId,
      segment: 'reject',
      body: <String, Object?>{'reason': justification.trim()},
    );
  }

  @override
  Future<Decision> requestRevision(
    String decisionId, {
    required String comment,
  }) async {
    if (comment.trim().isEmpty) {
      throw ArgumentError.value(
        comment,
        'comment',
        'A revision request requires a comment.',
      );
    }
    return _resolve(
      decisionId,
      segment: 'request-revision',
      body: <String, Object?>{'reason': comment.trim()},
    );
  }

  @override
  Future<Decision> discuss(String decisionId, {required String comment}) async {
    if (comment.trim().isEmpty) {
      throw ArgumentError.value(
        comment,
        'comment',
        'A comment cannot be empty.',
      );
    }
    throw const DecisionRepositoryException(
      'Discussing a decision is not supported by the server yet.',
    );
  }

  Future<Decision> _resolve(
    String decisionId, {
    required String segment,
    required Map<String, Object?> body,
  }) async {
    final GatewayContext context = await _requireContext();
    final int revision = await _revisionOf(context, decisionId);

    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .postUrl(_endpoint(context.server, '$_basePath/$decisionId/$segment'))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${context.accessToken}',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.ifMatchHeader, '"$revision"');
      request.add(utf8.encode(jsonEncode(body)));
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final Map<String, Object?> decoded = await _decodeBody(response);

      if (response.statusCode == HttpStatus.notFound) {
        throw DecisionNotFoundException(decisionId);
      }
      if (response.statusCode == HttpStatus.preconditionFailed ||
          response.statusCode == HttpStatus.conflict) {
        throw DecisionConflictException(
          _messageOf(
            decoded,
            fallback:
                'This decision changed since you last read it. Re-read it '
                'and decide again.',
          ),
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        throw DecisionRepositoryException(
          _messageOf(
            decoded,
            fallback: 'The server refused to $segment this decision.',
          ),
        );
      }
      return _decisionFromJson(decoded);
    } on SocketException {
      throw const DecisionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const DecisionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } on TimeoutException {
      throw const DecisionRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// The decision's current revision, read fresh — see the class doc's "why
  /// every resolve call reads before it writes".
  Future<int> _revisionOf(GatewayContext context, String decisionId) async {
    final _JsonResponse response = await _get(
      context,
      '$_basePath/$decisionId',
    );
    if (response.statusCode == HttpStatus.notFound) {
      throw DecisionNotFoundException(decisionId);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DecisionRepositoryException(
        _messageOf(
          response.body,
          fallback: 'Unable to read this decision before resolving it.',
        ),
      );
    }
    final Object? revision = response.body['revision'];
    if (revision is! int) {
      throw const DecisionRepositoryException(
        'The server answered a decision without a revision.',
      );
    }
    return revision;
  }

  Future<GatewayContext> _requireContext() async {
    final GatewayContext? context = await _resolveContext();
    if (context == null) {
      throw const DecisionRepositoryException(
        'Select a server and sign in to use Decisions.',
      );
    }
    return context;
  }

  Future<_JsonResponse> _get(GatewayContext context, String path) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .getUrl(_endpoint(context.server, path))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${context.accessToken}',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final Map<String, Object?> body = await _decodeBody(response);
      return _JsonResponse(statusCode: response.statusCode, body: body);
    } on SocketException {
      throw const DecisionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const DecisionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } on TimeoutException {
      throw const DecisionRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, Object?>> _decodeBody(HttpClientResponse response) async {
    final String raw = await utf8.decoder.bind(response).join().timeout(
      timeout,
    );
    final Object? decoded;
    try {
      decoded = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
    } on FormatException {
      throw const DecisionRepositoryException(
        'The server answered with something that was not JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const DecisionRepositoryException(
        'The server answered an unexpected JSON shape.',
      );
    }
    return decoded;
  }

  static Uri _endpoint(Uri server, String path) =>
      server.replace(path: '${server.path}$path');

  static String _messageOf(
    Map<String, Object?> body, {
    required String fallback,
  }) {
    final Object? message = body['message'];
    return message is String && message.isNotEmpty ? message : fallback;
  }
}

/// Mobile representation of `gateway/app/api/routes/decisions.py`'s
/// `_decision_dto`: `{id, projectId, executorId, request, mode, state, risk,
/// urgency, revision, requestedBy, rationale, createdAt, deadline,
/// decidedAt}`.
///
/// Several [Decision] fields have no server counterpart today —
/// `impactSummary`, `recommendationSummary`, `context`, `riskDetails`,
/// `evidence`, `affectedEntities`, `discussion` — the contract's own `Decision`
/// schema documents this: "no submission path in this build populates them".
/// They default empty here rather than fabricate content, matching what the
/// server itself says about them.
///
/// [Decision.auditTrail] is the one exception: the server has no full
/// history, but it does report the single most recent resolution
/// (`rationale`/`decidedAt`), so a resolved decision gets exactly one
/// synthesized entry rather than showing "No resolution actions yet." next
/// to a state badge that says otherwise. The resolving actor's identity is
/// not part of this response (only who *requested* the decision is), so the
/// synthesized entry names it `'Unknown actor'` rather than misattributing it
/// to the requester.
Decision _decisionFromJson(Map<String, Object?> json) {
  final String? id = _nonEmpty(json['id']);
  final String? projectId = _nonEmpty(json['projectId']);
  final String? request = json['request'] is String
      ? json['request']! as String
      : null;
  final DecisionState? state = json['state'] is String
      ? _parseState(json['state']! as String)
      : null;
  final DateTime? createdAt = _instant(json['createdAt']);
  final DateTime? deadline = _instant(json['deadline']);
  if (id == null ||
      projectId == null ||
      request == null ||
      state == null ||
      createdAt == null ||
      deadline == null) {
    throw const DecisionRepositoryException(
      'The server answered an unexpected decision shape.',
    );
  }

  final String requestedBy = _nonEmpty(json['requestedBy']) ?? 'Unknown';
  final String? rationale = _nonEmpty(json['rationale']);
  final DateTime? decidedAt = _instant(json['decidedAt']);
  final DecisionAuditAction? resolutionAction = _auditActionFor(state);

  return Decision(
    id: id,
    projectId: projectId,
    title: request,
    requestedBy: requestedBy,
    requestedAt: createdAt,
    urgency: _parseUrgency(json['urgency']),
    risk: _parseRisk(json['risk']),
    state: state,
    deadline: deadline,
    impactSummary: '',
    recommendationSummary: '',
    auditTrail: resolutionAction == null
        ? const <DecisionAuditEvent>[]
        : <DecisionAuditEvent>[
            DecisionAuditEvent(
              id: '$id-resolution',
              action: resolutionAction,
              actor: 'Unknown actor',
              occurredAt: decidedAt ?? createdAt,
              comment: rationale,
            ),
          ],
  );
}

DecisionState? _parseState(String raw) => switch (raw) {
  'pending' => DecisionState.pending,
  'approved' => DecisionState.approved,
  'rejected' => DecisionState.rejected,
  'revision_requested' => DecisionState.needsRevision,
  _ => null,
};

/// The audit action a resolved [DecisionState] corresponds to, or `null` for
/// [DecisionState.pending] — nothing to synthesize an entry for yet.
DecisionAuditAction? _auditActionFor(DecisionState state) => switch (state) {
  DecisionState.approved => DecisionAuditAction.approved,
  DecisionState.rejected => DecisionAuditAction.rejected,
  DecisionState.needsRevision => DecisionAuditAction.revisionRequested,
  DecisionState.pending => null,
};

/// `TaskPriority` (`shared/protocol.py`) only ever sends `low`/`normal`/
/// `high` today; an unrecognized or missing value defaults to `normal`
/// rather than failing the whole decision — urgency is a triage hint, not a
/// safety-critical field, so guessing conservatively is preferable to
/// refusing to show the decision at all.
DecisionUrgency _parseUrgency(Object? raw) {
  if (raw is! String) {
    return DecisionUrgency.normal;
  }
  return switch (raw) {
    'low' => DecisionUrgency.low,
    'normal' => DecisionUrgency.normal,
    'high' => DecisionUrgency.high,
    'critical' => DecisionUrgency.critical,
    _ => DecisionUrgency.normal,
  };
}

/// `DecisionRiskLevel` (`sensitive`/`controlled_write`/`read`, or `null`)
/// mapped onto [DecisionRisk]'s three severities. `sensitive` is the only
/// value this backend produces today (`gateway/app/api/routes/decisions.py`
/// module docstring) and maps to [DecisionRisk.high]; an unrecognized or
/// missing value defaults to [DecisionRisk.high] too — biasing toward
/// caution is the safe direction for a field that gates how much scrutiny an
/// operator gives a decision before approving it.
DecisionRisk _parseRisk(Object? raw) {
  if (raw is! String) {
    return DecisionRisk.high;
  }
  return switch (raw) {
    'sensitive' => DecisionRisk.high,
    'controlled_write' => DecisionRisk.medium,
    'read' => DecisionRisk.low,
    _ => DecisionRisk.high,
  };
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _instant(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, Object?> body;
}
