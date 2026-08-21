import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/project_health.dart';
import '../domain/project_repository.dart';
import '../domain/project_summary.dart';

/// Talks to the real Codex Bridge projects endpoints
/// (`gateway/app/api/routes/projects.py`,
/// `docs/api/codex-bridge.openapi.yaml` "projects" — CodexBridge issue #5).
///
/// Structured like [HttpLiveSessionRepository] and [HttpAuthGateway]: a
/// plain `dart:io` `HttpClient` per call, certificate verification never
/// disabled, and — unlike `HttpLiveSessionRepository`, which shipped with
/// none of its own calls time-bounded (`docs/napkin-lessons.md`,
/// 2026-08-21) — every step here (connect, request, response headers,
/// response body) is bounded by [timeout], so a server that accepts the
/// socket and then stalls cannot hang the projects list or a project's
/// dashboard forever.
///
/// ## The health vocabulary does not line up 1:1
///
/// This app's domain [ProjectHealth] (`active`/`unhealthy`/`pendingDecision`
/// /`offline`, `lib/features/projects/domain/project_health.dart`) was
/// drafted before CodexBridge issue #5 shipped its own `ProjectHealth`
/// (`ok`/`degraded`/`unknown`/`disabled`) — four values with different
/// meanings, not four spellings of the same thing:
///
/// - `disabled` is an **operator decision** ("turned off in the registry"),
///   not an incident.
/// - `unknown` means no executor is even assigned to the project — there is
///   nothing to judge liveness from.
/// - `degraded` means executors are assigned but none of them is live right
///   now.
/// - `ok` means at least one assigned executor is live.
///
/// None of those four says anything about a pending decision — that arrives
/// as a separate `pendingDecisions` count alongside `health`, not as a value
/// of it. [projectHealthFromBackend] maps the pair onto this app's single
/// enum rather than widening [ProjectHealth] itself, which is #23/#24
/// presentation-layer territory this change does not touch. Reported to the
/// operator as a judgment call, the same shape the auth work's
/// access-code-vs-username/password gap was reported earlier today
/// (`docs/napkin-lessons.md`, "2026-08-21 — WK-20260821-http-auth-gateway").
class HttpProjectRepository implements ProjectRepository {
  const HttpProjectRepository({this.timeout = const Duration(seconds: 10)});

  /// Applied to the connection, to each request and to reading each
  /// response body.
  final Duration timeout;

  static const String _projectsPath = '/api/v1/projects';

  @override
  Future<List<ProjectSummary>> loadProjects({
    required Uri server,
    required String accessToken,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final _JsonResponse response = await _get(
        client,
        _endpoint(server, _projectsPath),
        accessToken,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw ProjectRepositoryException(_failureMessage(response));
      }
      final Map<String, Object?> body = _decodeObject(response.body);
      final Object? items = body['items'];
      if (items is! List<Object?>) {
        throw const ProjectRepositoryException(
          'The server answered without a projects list.',
        );
      }
      return items
          .whereType<Map<String, Object?>>()
          .map(_summaryFromJson)
          .toList(growable: false);
    } on ProjectRepositoryException {
      rethrow;
    } on Object {
      throw const ProjectRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<ProjectSummary?> loadProject({
    required Uri server,
    required String accessToken,
    required String id,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final _JsonResponse response = await _get(
        client,
        _endpoint(server, '$_projectsPath/${Uri.encodeComponent(id)}'),
        accessToken,
      );
      if (response.statusCode == HttpStatus.notFound) {
        // Not-found and "exists but outside your visible scope" are the
        // same response on this backend, by design — see the class doc.
        // This must read as "no such project", not as a generic failure.
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw ProjectRepositoryException(_failureMessage(response));
      }
      return _summaryFromJson(_decodeObject(response.body));
    } on ProjectRepositoryException {
      rethrow;
    } on Object {
      throw const ProjectRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_JsonResponse> _get(
    HttpClient client,
    Uri uri,
    String accessToken,
  ) async {
    final HttpClientRequest request = await client.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final HttpClientResponse response = await request.close().timeout(timeout);
    final String body = await utf8.decoder.bind(response).join().timeout(timeout);
    return _JsonResponse(statusCode: response.statusCode, body: body);
  }

  static String _failureMessage(_JsonResponse response) {
    if (response.statusCode == HttpStatus.unauthorized) {
      return 'Your session is no longer valid. Sign in again.';
    }
    final Map<String, Object?>? decoded = _tryDecodeObject(response.body);
    final String? message =
        decoded != null && decoded['message'] is String
        ? decoded['message']! as String
        : null;
    return (message != null && message.isNotEmpty)
        ? message
        : 'Unable to load projects.';
  }

  static Uri _endpoint(Uri server, String path) =>
      server.replace(path: '${server.path}$path');
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Maps CodexBridge's `ProjectHealth` + `pendingDecisions` onto this app's
/// [ProjectHealth] and a short, card-visible [ProjectSummary.attentionSummary].
/// Pulled out as a pure function — no client, no JSON — so the mapping
/// decision is unit-testable on its own (`design-standards.md` §1).
(ProjectHealth, String?) projectHealthFromBackend({
  required bool enabled,
  required String backendHealth,
  required int pendingDecisions,
}) {
  if (!enabled) {
    return (ProjectHealth.offline, 'Disabled in the registry');
  }
  switch (backendHealth) {
    case 'degraded':
      return (ProjectHealth.unhealthy, 'No live executor connected');
    case 'unknown':
      return (ProjectHealth.offline, 'No executor assigned to this project');
    case 'ok':
      if (pendingDecisions > 0) {
        final String plural = pendingDecisions == 1 ? '' : 's';
        return (
          ProjectHealth.pendingDecision,
          '$pendingDecisions decision$plural waiting your review',
        );
      }
      return (ProjectHealth.active, null);
    default:
      // An unrecognized value from a future server build: fail closed by
      // flagging it as needing attention instead of silently rendering
      // "Active" for a state this client does not understand.
      return (ProjectHealth.unhealthy, 'Unrecognized health: $backendHealth');
  }
}

ProjectSummary _summaryFromJson(Map<String, Object?> json) {
  final String? id = _string(json['id']);
  final String? name = _string(json['name']);
  final bool? enabled = json['enabled'] is bool ? json['enabled']! as bool : null;
  final String? backendHealth = _string(json['health']);
  final int pendingDecisions = _int(json['pendingDecisions']) ?? 0;
  if (id == null || name == null || enabled == null || backendHealth == null) {
    throw const ProjectRepositoryException(
      'The server answered a project in an unexpected shape.',
    );
  }
  final (ProjectHealth health, String? attentionSummary) =
      projectHealthFromBackend(
        enabled: enabled,
        backendHealth: backendHealth,
        pendingDecisions: pendingDecisions,
      );
  return ProjectSummary(
    id: id,
    name: name,
    health: health,
    attentionSummary: attentionSummary,
  );
}

Map<String, Object?> _decodeObject(String raw) {
  final Map<String, Object?>? decoded = _tryDecodeObject(raw);
  if (decoded == null) {
    throw const ProjectRepositoryException(
      'The server answered with something that was not JSON.',
    );
  }
  return decoded;
}

Map<String, Object?>? _tryDecodeObject(String raw) {
  if (raw.isEmpty) {
    return <String, Object?>{};
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  return decoded is Map<String, Object?> ? decoded : null;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is int ? value : null;
