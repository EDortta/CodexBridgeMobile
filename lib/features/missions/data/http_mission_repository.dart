import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/mission.dart';
import '../domain/mission_explanation.dart';
import '../domain/mission_repository.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_stage.dart';
import '../domain/mission_state.dart';
import '../domain/mission_timeline_event.dart';

/// Talks to the real Codex Bridge mission endpoints —
/// `gateway/app/api/routes/missions.py` /
/// `docs/api/codex-bridge.openapi.yaml`'s `missions` section — for
/// `loadMissions`/`loadMission`/`cancel`/`explain`.
///
/// **`pause` and `resume` have no server counterpart.** The gateway's own
/// module docstring is explicit about this: `cancel` is the only lifecycle
/// command the agent protocol defines for a mission (`task.cancel`);
/// `pause`/`resume` need protocol and executor work the gateway does not yet
/// have (issue #16) and are "deliberately absent rather than present and
/// inert". Both methods here fail closed with
/// [MissionControlNotAllowedException] before any request is sent, rather
/// than pretending to call an endpoint that does not exist.
///
/// **The mission-control fields this build's real gateway reports are
/// thinner than [Mission]'s.** A real mission is the same execution row a
/// live session is, reframed (`id`, `projectId`, `assignedAgent`, `state`,
/// a coarse `stage` over three buckets, a coarse `risk` over three policy
/// levels, `blocked`/`blockedReason`, `revision`) — there is no `title`
/// distinct from `objective`, no editorial `progress` percentage, and no
/// `dependencies`/`tests`/`files`/`artifacts`/`relatedDecisionIds` (the
/// gateway's own contract says so explicitly: nothing in that codebase's
/// domain model links one mission to another or to any other entity yet, and
/// it deliberately does not ship an always-empty array a client could build
/// UI around and never see populated). Rather than reshape [Mission] and
/// every screen that renders it — out of scope for this change — the
/// mapping below fills the gap with clearly-documented, lossy
/// approximations: see [_missionFromDto]. This is the single biggest
/// judgment call in this file; a follow-up that reconciles [Mission] with
/// what the gateway actually reports is the honest fix.
///
/// Structured like [HttpAuthGateway] and [HttpLiveSessionRepository]: a
/// plain `dart:io` [HttpClient] per call, certificate verification never
/// disabled, every timeout applied per call rather than left to the platform
/// default, and every transport failure caught at the one boundary instead
/// of leaking past whichever call site forgot to guard it.
///
/// [resolveContext] mirrors [HttpAuthGateway]'s `resolveServer` seam: this
/// class does not import `core/gateway/` itself (a `data/` file staying
/// decoupled from that composition, same as `HttpLiveSessionRepository`
/// staying decoupled from `features/auth/`), so the caller — `lib/app/`,
/// the one layer allowed to import both the gateway context and this file —
/// supplies a callback that resolves the selected server and the
/// signed-in session's access token as one pair, or `null` when neither is
/// available yet.
class HttpMissionRepository implements MissionRepository {
  const HttpMissionRepository(
    this.resolveContext, {
    this.timeout = const Duration(seconds: 10),
  });

  /// Resolves `(server, accessToken)`, or `null` when no server is selected
  /// or no session is signed in.
  final Future<(Uri, String)?> Function() resolveContext;

  final Duration timeout;

  static const String _notConfigured =
      'Select a server and sign in to reach missions.';

  @override
  Future<List<Mission>> loadMissions() async {
    final _Context context = await _requireContext();
    final Map<String, Object?> body = await _getJsonObject(
      context,
      // No cursor pagination client-side yet (v1): a single page at the
      // contract's own maximum, the same simplification `loadSessionLogs`
      // makes for a bounded window rather than a fully paged stream.
      '/api/v1/missions?limit=200',
      fallback: 'Unable to load missions.',
    );
    final Object? items = body['items'];
    if (items is! List<Object?>) {
      throw const MissionRepositoryException(
        'The server answered without a missions list.',
      );
    }
    try {
      return items
          .whereType<Map<String, Object?>>()
          .map((Map<String, Object?> dto) => _missionFromDto(dto))
          .toList(growable: false);
    } on FormatException {
      throw const MissionRepositoryException(
        'The server answered an unexpected mission shape.',
      );
    }
  }

  @override
  Future<Mission> loadMission(String missionId) async {
    final _Context context = await _requireContext();
    final Map<String, Object?> dto = await _getMissionDto(context, missionId);
    final List<MissionTimelineEvent> timeline = await _loadTimeline(
      context,
      missionId,
    );
    try {
      return _missionFromDto(dto, timeline: timeline);
    } on FormatException {
      throw const MissionRepositoryException(
        'The server answered an unexpected mission shape.',
      );
    }
  }

  @override
  Future<Mission> pause(String missionId) async {
    throw MissionControlNotAllowedException(
      missionId,
      'Pause is not supported by this server — a mission can only be cancelled.',
    );
  }

  @override
  Future<Mission> resume(String missionId) async {
    throw MissionControlNotAllowedException(
      missionId,
      'Resume is not supported by this server — a mission can only be cancelled.',
    );
  }

  @override
  Future<Mission> cancel(String missionId, {required String reason}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A cancellation requires a reason.');
    }
    final _Context context = await _requireContext();

    // The gateway's `POST /missions/{id}/cancel` has no request body — the
    // reason the operator typed here has nowhere to go. It is validated
    // above (so Mock and Http agree on the precondition) but not sent: the
    // real timeline will read "Cancelled by an operator.", not the reason
    // text, until the contract grows a field for it. Documented again in
    // `docs/napkin-lessons.md` and called out in this PR's own description —
    // this is a product gap, not an oversight.

    // `If-Match` must name the revision from the read that produced the
    // value being changed (`docs/api/codex-bridge.openapi.yaml`,
    // `IfMatch`). Fetched fresh, immediately before the write, rather than
    // threaded through the interface as a caller-supplied parameter: the
    // interface has exactly one call site (`MissionDetailScreen`'s
    // `_ActionsCard`), so there is no cached-list revision worth reusing —
    // `live_session_providers.dart`'s own comment on this exact trade-off
    // "the revision sent is never a stale copy of one the detail screen's
    // own, independently loaded [entity] has already moved past" is the
    // reasoning that applies here too, just with nothing else to check
    // first.
    final Map<String, Object?> fresh = await _getMissionDto(context, missionId);
    final int revision = _int(fresh['revision']) ?? (throw const MissionRepositoryException(
      'The server answered a mission with no revision.',
    ));

    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .postUrl(_endpoint(context.server, '/api/v1/missions/$missionId/cancel'))
          .timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${context.accessToken}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.ifMatchHeader, '"$revision"');
      final HttpClientResponse response = await request.close().timeout(timeout);
      final Map<String, Object?> body = await _jsonObject(response, timeout: timeout);

      switch (response.statusCode) {
        case HttpStatus.ok:
          try {
            return _missionFromDto(body);
          } on FormatException {
            throw const MissionRepositoryException(
              'The server answered an unexpected mission shape.',
            );
          }
        case HttpStatus.notFound:
          throw MissionNotFoundException(missionId);
        case HttpStatus.conflict: // 409: not in a cancellable state.
        case HttpStatus.preconditionFailed: // 412: stale revision.
          throw MissionControlNotAllowedException(
            missionId,
            _messageOf(body, fallback: 'This mission cannot be cancelled right now.'),
          );
        default:
          throw MissionRepositoryException(
            _messageOf(body, fallback: 'The server refused to cancel this mission.'),
          );
      }
    } on TimeoutException {
      throw const MissionRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } on SocketException {
      throw const MissionRepositoryException('The Codex Bridge server did not answer.');
    } on HandshakeException {
      throw const MissionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<MissionExplanation> explain(String missionId) async {
    final _Context context = await _requireContext();
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .postUrl(_endpoint(context.server, '/api/v1/missions/$missionId/explain'))
          .timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${context.accessToken}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close().timeout(timeout);
      final Map<String, Object?> body = await _jsonObject(response, timeout: timeout);
      if (response.statusCode == HttpStatus.notFound) {
        throw MissionNotFoundException(missionId);
      }
      if (response.statusCode != HttpStatus.ok) {
        throw MissionRepositoryException(
          _messageOf(body, fallback: 'Unable to explain this mission.'),
        );
      }
      try {
        return MissionExplanation.fromJson(body);
      } on FormatException {
        throw const MissionRepositoryException(
          'The server answered an unexpected explanation shape.',
        );
      }
    } on TimeoutException {
      throw const MissionRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } on SocketException {
      throw const MissionRepositoryException('The Codex Bridge server did not answer.');
    } on HandshakeException {
      throw const MissionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<MissionTimelineEvent>> _loadTimeline(
    _Context context,
    String missionId,
  ) async {
    final Map<String, Object?> body = await _getJsonObject(
      context,
      // Cursor-paginated server-side (oldest first); a single page at the
      // contract's maximum, same v1 simplification as `loadMissions`.
      '/api/v1/missions/$missionId/timeline?limit=200',
      fallback: 'Unable to load this mission\'s timeline.',
    );
    final Object? items = body['items'];
    if (items is! List<Object?>) {
      throw const MissionRepositoryException(
        'The server answered without a timeline.',
      );
    }
    int index = 0;
    return items.whereType<Map<String, Object?>>().map((Map<String, Object?> event) {
      index += 1;
      final String type = _string(event['type']) ?? 'task.event';
      final DateTime? at = _instant(event['at']);
      final String summary = _string(event['summary']) ?? type;
      if (at == null) {
        throw const FormatException('invalid_timeline_event');
      }
      return MissionTimelineEvent(
        // No `id` in the wire shape (`MissionTimelineEvent` in the
        // contract carries `type`/`at`/`state`/`actor`/`summary`, not an
        // id) — synthesized from the mission id and this page's position,
        // same "stable enough for a widget key, not a server identity"
        // shape `MockMissionRepository._transition` already uses for its
        // own local timeline entries.
        id: '$missionId-timeline-$index',
        description: summary,
        actor: _string(event['actor']) ?? 'System',
        occurredAt: at,
      );
    }).toList(growable: false);
  }

  /// Maps the gateway's `Mission` DTO onto this app's [Mission] domain
  /// model. See this class's own doc comment for why several fields here
  /// are lossy approximations rather than a direct field-for-field mapping.
  static Mission _missionFromDto(
    Map<String, Object?> dto, {
    List<MissionTimelineEvent> timeline = const <MissionTimelineEvent>[],
  }) {
    final String? id = _string(dto['id']);
    final String? projectId = _string(dto['projectId']);
    final String? assignedAgent = _string(dto['assignedAgent']);
    final String? rawState = _string(dto['state']);
    final bool? blocked = dto['blocked'] is bool ? dto['blocked']! as bool : null;
    final DateTime? createdAt = _instant(dto['createdAt']);
    if (id == null ||
        projectId == null ||
        assignedAgent == null ||
        rawState == null ||
        blocked == null ||
        createdAt == null) {
      throw const FormatException('invalid_mission_payload');
    }

    final String objective = _string(dto['objective']) ?? '';
    final String? blockedSummary = dto['blockedReason'] is Map<String, Object?>
        ? _string((dto['blockedReason']! as Map<String, Object?>)['summary'])
        : null;
    final MissionState state = _missionState(
      blocked: blocked,
      rawState: rawState,
    );
    final bool terminal = state == MissionState.completed || state == MissionState.cancelled;

    return Mission(
      id: id,
      projectId: projectId,
      title: objective.isNotEmpty ? objective : 'Mission $id',
      status: _humanize(rawState),
      // `MissionStage`/`MissionRisk` are a richer, 5- and 3-value local
      // taxonomy (`planning`..`documentation`, `high`/`medium`/`low`) that
      // predates this class; the real gateway only ever reports a coarse
      // 3-value `stage` (`pending`/`active`/`done`, a grouping over
      // execution state, not software-development phase) and a 3-value
      // `risk` (`read`/`controlled_write`/`sensitive`, a policy level, not
      // an editorial risk rating). Mapped by ordinal position — the closest
      // defensible approximation, not a claim that these mean the same
      // thing.
      stage: _missionStage(_string(dto['stage'])),
      risk: _missionRisk(_string(dto['risk'])),
      state: state,
      owner: assignedAgent,
      // No progress percentage in the real contract: 1.0 once the mission
      // is in the gateway's own "done" bucket, 0.0 otherwise. A coarse
      // done/not-done signal, not a claim of fine-grained completion.
      progress: terminal ? 1.0 : 0.0,
      startedAt: _instant(dto['startedAt']) ?? createdAt,
      latestEvent: blockedSummary ?? _string(dto['lastError']) ?? _humanize(rawState),
      blockedReason: blockedSummary,
      objective: objective,
      timeline: timeline,
    );
  }

  static MissionState _missionState({required bool blocked, required String rawState}) {
    if (blocked) {
      return MissionState.blocked;
    }
    return switch (rawState) {
      'paused' => MissionState.paused,
      'completed' => MissionState.completed,
      'cancelled' || 'failed' || 'expired' || 'lost' => MissionState.cancelled,
      _ => MissionState.active, // queued, waiting_executor, running, pausing, resuming, restarting
    };
  }

  static MissionStage _missionStage(String? raw) => switch (raw) {
    'pending' => MissionStage.planning,
    'active' => MissionStage.implementation,
    'done' => MissionStage.documentation,
    _ => MissionStage.planning,
  };

  static MissionRisk _missionRisk(String? raw) => switch (raw) {
    'read' => MissionRisk.low,
    'controlled_write' => MissionRisk.medium,
    'sensitive' => MissionRisk.high,
    _ => MissionRisk.medium,
  };

  static String _humanize(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final String spaced = raw.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  Future<_Context> _requireContext() async {
    final (Uri, String)? resolved = await resolveContext();
    if (resolved == null) {
      throw const MissionRepositoryException(_notConfigured);
    }
    return _Context(server: resolved.$1, accessToken: resolved.$2);
  }

  Future<Map<String, Object?>> _getMissionDto(_Context context, String missionId) async {
    return _getJsonObject(
      context,
      '/api/v1/missions/$missionId',
      fallback: 'Unable to load this mission.',
      notFoundIsMissionId: missionId,
    );
  }

  Future<Map<String, Object?>> _getJsonObject(
    _Context context,
    String path, {
    required String fallback,
    String? notFoundIsMissionId,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .getUrl(_endpoint(context.server, path))
          .timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${context.accessToken}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close().timeout(timeout);
      final Map<String, Object?> body = await _jsonObject(response, timeout: timeout);
      if (response.statusCode == HttpStatus.notFound && notFoundIsMissionId != null) {
        throw MissionNotFoundException(notFoundIsMissionId);
      }
      if (response.statusCode != HttpStatus.ok) {
        throw MissionRepositoryException(_messageOf(body, fallback: fallback));
      }
      return body;
    } on TimeoutException {
      throw const MissionRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } on SocketException {
      throw const MissionRepositoryException('The Codex Bridge server did not answer.');
    } on HandshakeException {
      throw const MissionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Uri _endpoint(Uri server, String path) {
    final Uri parsed = Uri.parse(path);
    return server.replace(
      path: '${server.path}${parsed.path}',
      queryParameters: parsed.queryParametersAll.isEmpty ? null : parsed.queryParametersAll,
    );
  }

  static Future<Map<String, Object?>> _jsonObject(
    HttpClientResponse response, {
    required Duration timeout,
  }) async {
    final String raw = await utf8.decoder.bind(response).join().timeout(timeout);
    final Object? decoded;
    try {
      decoded = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
    } on FormatException {
      throw const MissionRepositoryException(
        'The server answered with something that was not JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const MissionRepositoryException(
        'The server answered an unexpected JSON shape.',
      );
    }
    return decoded;
  }

  static String _messageOf(Map<String, Object?> body, {required String fallback}) {
    final String? message = body['message'] is String ? body['message']! as String : null;
    return (message != null && message.isNotEmpty) ? message : fallback;
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _int(Object? value) => value is int ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class _Context {
  const _Context({required this.server, required this.accessToken});

  final Uri server;
  final String accessToken;
}
