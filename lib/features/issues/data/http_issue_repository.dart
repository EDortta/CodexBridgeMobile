import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/gateway/gateway_context.dart';
import '../domain/epic.dart';
import '../domain/issue_repository.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';

/// Talks to the real Codex Bridge epics/issues endpoints (`EDortta/CodexBridge`
/// issue #8, `gateway/app/api/routes/epics.py` and `.../issues.py`).
///
/// **The interface it satisfies is narrower than the gateway it calls.**
/// [IssueRepository] is load-only and never took a project id — #29 shipped
/// it that way, and every screen that consumes it still expects "every epic
/// / every issue, I will filter" (`filterEpics`, `filterIssues`,
/// `epics_screen.dart`, `issues_screen.dart`). The gateway itself has no such
/// endpoint: `GET /api/v1/projects/{projectId}/epics` and
/// `.../issues` are both project-scoped, and there is no
/// `GET /api/v1/epics/{epicId}` at all. Rather than reshape the interface
/// and the routing that would need to carry a project id down to
/// `EpicDetailScreen` (a change #29's UI was never built to need), this class
/// closes the gap itself: [loadEpics] and [loadIssues] fan out across every
/// project the signed-in operator can see (`GET /api/v1/projects`) and
/// concatenate each project's page; [loadEpic] does the same search and
/// keeps the first match. More requests than a single project-scoped call,
/// acceptable for a browser sized like this one's — named here rather than
/// silently paid on every screen visit.
///
/// **Two vocabularies exist because the mobile UI predates the real one.**
/// `IssueStatus`/`IssuePriority` are the four-value sets #29 designed
/// `filterEpics`/`filterIssues`/every status chip around; the gateway's
/// columns are wider (`issue_types.py`: six issue statuses, four epic
/// statuses, four priorities with different names). [_issueStatusFromWire]
/// and friends fold the wire vocabulary into the UI's rather than widening
/// every enum, chip and filter menu #29 already shipped and tested — see
/// each mapping's own doc comment for the specific collisions this makes
/// (`in_review` folds into "In progress", `cancelled` folds into "Done").
/// [_issueStatusToWire] and friends invert the same table for the write
/// methods below, which are not yet part of [IssueRepository] — see their
/// own doc comment for why.
///
/// Structured like [HttpAuthGateway] (bounded timeouts, a plain `dart:io`
/// [HttpClient] per call, certificate verification never disabled) and like
/// `HttpLiveSessionRepository` (`features/missions/data/`) for the JSON
/// envelope and `If-Match` handling.
class HttpIssueRepository implements IssueRepository {
  const HttpIssueRepository(
    this.resolveContext, {
    this.timeout = const Duration(seconds: 10),
  });

  /// Resolves the signed-in operator's server and access token, or `null`
  /// when neither is available. Injected rather than read from a feature
  /// provider, so `features/issues/data/` never imports another feature's
  /// `presentation/` layer (`docs/architecture/state-architecture.md`) —
  /// composed in `lib/app/issue_repository_binding.dart` instead, exactly
  /// like [HttpAuthGateway]'s `resolveServer`.
  final Future<GatewayContext?> Function() resolveContext;

  /// Applied to the connection, to each request and to reading each body —
  /// the same discipline [HttpAuthGateway] applies to its own calls.
  final Duration timeout;

  /// Safety bound on cursor-following in [_listAllPages]: a page or a
  /// project count this high is not a real fleet this app expects to browse,
  /// and a server that never sets `hasMore: false` must not hang the
  /// screen forever.
  static const int _maxPages = 50;

  @override
  Future<List<ProjectIssue>> loadIssues() async {
    final GatewayContext context = await _requireContext();
    final List<String> projectIds = await _visibleProjectIds(context);
    final List<ProjectIssue> issues = <ProjectIssue>[];
    for (final String projectId in projectIds) {
      final List<Map<String, Object?>> rows = await _listAllPages(
        context,
        '/api/v1/projects/$projectId/issues',
      );
      issues.addAll(rows.map(_issueFromJson));
    }
    return issues;
  }

  @override
  Future<List<Epic>> loadEpics() async {
    final GatewayContext context = await _requireContext();
    final List<String> projectIds = await _visibleProjectIds(context);
    final Map<String, List<String>> issueIdsByEpic = <String, List<String>>{};
    final List<Map<String, Object?>> epicRows = <Map<String, Object?>>[];
    for (final String projectId in projectIds) {
      final List<Map<String, Object?>> issueRows = await _listAllPages(
        context,
        '/api/v1/projects/$projectId/issues',
      );
      _indexByEpic(issueRows, into: issueIdsByEpic);
      epicRows.addAll(
        await _listAllPages(context, '/api/v1/projects/$projectId/epics'),
      );
    }
    return epicRows
        .map(
          (Map<String, Object?> row) => _epicFromJson(
            row,
            issueIds: issueIdsByEpic[row['id']] ?? const <String>[],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ProjectIssue> loadIssue(String issueId) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _call(
      context,
      'GET',
      '/api/v1/issues/$issueId',
    );
    if (response.statusCode == HttpStatus.notFound) {
      throw IssueNotFoundException(issueId);
    }
    return _issueFromJson(_decodeSuccess(response, HttpStatus.ok));
  }

  @override
  Future<Epic> loadEpic(String epicId) async {
    final GatewayContext context = await _requireContext();
    final List<String> projectIds = await _visibleProjectIds(context);
    for (final String projectId in projectIds) {
      final List<Map<String, Object?>> epicRows = await _listAllPages(
        context,
        '/api/v1/projects/$projectId/epics',
      );
      final Map<String, Object?>? match = epicRows
          .cast<Map<String, Object?>?>()
          .firstWhere(
            (Map<String, Object?>? row) => row?['id'] == epicId,
            orElse: () => null,
          );
      if (match == null) {
        continue;
      }
      final List<Map<String, Object?>> issueRows = await _listAllPages(
        context,
        '/api/v1/projects/$projectId/issues',
      );
      final Map<String, List<String>> issueIdsByEpic = <String, List<String>>{};
      _indexByEpic(issueRows, into: issueIdsByEpic);
      return _epicFromJson(
        match,
        issueIds: issueIdsByEpic[epicId] ?? const <String>[],
      );
    }
    throw EpicNotFoundException(epicId);
  }

  /// Creates an epic. Not part of [IssueRepository]: #29's browser is
  /// read-only and nothing in this app calls this yet — landed alongside the
  /// rest of this class because the gateway side is ready (issue #8) and
  /// #30 ("Issue creation, editing and planning review") will need it. The
  /// same shape [HttpAuthGateway.revoke] uses: real, tested, and named here
  /// rather than left to be rediscovered.
  Future<Epic> createEpic({
    required String projectId,
    required String title,
    String? description,
    IssueStatus? status,
  }) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _call(
      context,
      'POST',
      '/api/v1/epics',
      body: <String, Object?>{
        'projectId': projectId,
        'title': title,
        'description': ?description,
        'status': ?(status == null ? null : _epicStatusToWire(status)),
      },
    );
    return _epicFromJson(
      _decodeSuccess(response, HttpStatus.created),
      issueIds: const <String>[],
    );
  }

  /// Creates an issue. Not part of [IssueRepository] — see [createEpic].
  Future<ProjectIssue> createIssue({
    required String projectId,
    required String title,
    String? epicId,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  }) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _call(
      context,
      'POST',
      '/api/v1/issues',
      body: <String, Object?>{
        'projectId': projectId,
        'epicId': ?epicId,
        'title': title,
        'description': ?description,
        'status': ?(status == null ? null : _issueStatusToWire(status)),
        'priority': ?(priority == null ? null : _priorityToWire(priority)),
        'labels': ?labels,
        'assigneeUserId': ?assigneeUserId,
        'assigneeEmail': ?assigneeEmail,
        'dependencies': ?dependencies,
        'blockedReason': ?blockedReason,
      },
    );
    return _issueFromJson(_decodeSuccess(response, HttpStatus.created));
  }

  /// Changes fields on an existing issue, guarded by [revision] — the value
  /// last read from [ProjectIssue.revision] — sent as `If-Match`. Throws
  /// [StaleIssueRevisionException] when the gateway answers `412` because the
  /// issue changed since that read. Not part of [IssueRepository] — see
  /// [createEpic]. `epicId` is deliberately not a parameter here: the
  /// gateway keeps exactly one path that moves an issue between epics
  /// ([linkIssueToEpic]), not two that could disagree.
  Future<ProjectIssue> updateIssue({
    required String issueId,
    required int revision,
    String? title,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  }) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _call(
      context,
      'PATCH',
      '/api/v1/issues/$issueId',
      ifMatch: '"$revision"',
      body: <String, Object?>{
        'title': ?title,
        'description': ?description,
        'status': ?(status == null ? null : _issueStatusToWire(status)),
        'priority': ?(priority == null ? null : _priorityToWire(priority)),
        'labels': ?labels,
        'assigneeUserId': ?assigneeUserId,
        'assigneeEmail': ?assigneeEmail,
        'dependencies': ?dependencies,
        'blockedReason': ?blockedReason,
      },
    );
    if (response.statusCode == HttpStatus.preconditionFailed) {
      throw StaleIssueRevisionException(
        _messageOf(
          response,
          fallback: 'This issue changed since you last read it.',
        ),
      );
    }
    return _issueFromJson(_decodeSuccess(response, HttpStatus.ok));
  }

  /// Attaches [issueId] to [epicId], guarded by [issueRevision] — the
  /// gateway validates `If-Match` against the *issue's* revision, not the
  /// epic's (`epics.py`'s `link_issue`), and answers with the updated issue,
  /// not the epic. Throws [StaleIssueRevisionException] on `412`. Not part
  /// of [IssueRepository] — see [createEpic].
  Future<ProjectIssue> linkIssueToEpic({
    required String epicId,
    required String issueId,
    required int issueRevision,
  }) async {
    final GatewayContext context = await _requireContext();
    final _JsonResponse response = await _call(
      context,
      'POST',
      '/api/v1/epics/$epicId/issues/$issueId',
      ifMatch: '"$issueRevision"',
    );
    if (response.statusCode == HttpStatus.preconditionFailed) {
      throw StaleIssueRevisionException(
        _messageOf(
          response,
          fallback: 'This issue changed since you last read it.',
        ),
      );
    }
    return _issueFromJson(_decodeSuccess(response, HttpStatus.ok));
  }

  Future<GatewayContext> _requireContext() async {
    final GatewayContext? context = await resolveContext();
    if (context == null) {
      throw const IssueRepositoryException(
        'Select a server and sign in to load epics and issues.',
      );
    }
    return context;
  }

  Future<List<String>> _visibleProjectIds(GatewayContext context) async {
    final List<Map<String, Object?>> rows = await _listAllPages(
      context,
      '/api/v1/projects',
    );
    return rows
        .map((Map<String, Object?> row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
  }

  static void _indexByEpic(
    List<Map<String, Object?>> issueRows, {
    required Map<String, List<String>> into,
  }) {
    for (final Map<String, Object?> row in issueRows) {
      final Object? epicId = row['epicId'];
      final Object? issueId = row['id'];
      if (epicId is String && issueId is String) {
        (into[epicId] ??= <String>[]).add(issueId);
      }
    }
  }

  Future<List<Map<String, Object?>>> _listAllPages(
    GatewayContext context,
    String path,
  ) async {
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];
    String? cursor;
    for (int page = 0; page < _maxPages; page++) {
      final _JsonResponse response = await _call(
        context,
        'GET',
        path,
        query: cursor == null ? null : <String, String>{'cursor': cursor},
      );
      final Map<String, Object?> body = _decodeSuccess(response, HttpStatus.ok);
      final Object? items = body['items'];
      if (items is! List<Object?>) {
        throw const IssueRepositoryException(
          'The server answered without a list.',
        );
      }
      results.addAll(items.whereType<Map<String, Object?>>());
      final Object? pageInfo = body['page'];
      if (pageInfo is! Map<String, Object?> || pageInfo['hasMore'] != true) {
        break;
      }
      final Object? nextCursor = pageInfo['nextCursor'];
      if (nextCursor is! String) {
        break;
      }
      cursor = nextCursor;
    }
    return results;
  }

  Future<_JsonResponse> _call(
    GatewayContext context,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? ifMatch,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final Uri uri = _endpoint(context.server, path).replace(
        queryParameters: query,
      );
      final HttpClientRequest request = await switch (method) {
        'GET' => client.getUrl(uri),
        'POST' => client.postUrl(uri),
        'PATCH' => client.patchUrl(uri),
        _ => throw UnsupportedError('Unsupported method: $method'),
      }.timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${context.accessToken}',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (ifMatch != null) {
        request.headers.set(HttpHeaders.ifMatchHeader, ifMatch);
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final HttpClientResponse response = await request.close().timeout(timeout);
      final String raw = await utf8.decoder.bind(response).join().timeout(timeout);
      return _JsonResponse(statusCode: response.statusCode, body: raw);
    } on SocketException {
      throw const IssueRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const IssueRepositoryException(
        'The secure connection to the server was refused.',
      );
    } on TimeoutException {
      throw const IssueRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Uri _endpoint(Uri server, String path) =>
      server.replace(path: '${server.path}$path');

  static Map<String, Object?> _decodeSuccess(_JsonResponse response, int expected) {
    if (response.statusCode != expected) {
      throw IssueRepositoryException(
        _messageOf(
          response,
          fallback: 'The Codex Bridge server refused this request.',
        ),
      );
    }
    final Object? decoded;
    try {
      decoded = response.body.isEmpty ? <String, Object?>{} : jsonDecode(response.body);
    } on FormatException {
      throw const IssueRepositoryException(
        'The server answered with something that was not JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const IssueRepositoryException(
        'The server answered an unexpected JSON shape.',
      );
    }
    return decoded;
  }

  static String _messageOf(_JsonResponse response, {required String fallback}) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?> && decoded['message'] is String) {
        return decoded['message']! as String;
      }
    } on FormatException {
      // Fall through to fallback.
    }
    return fallback;
  }

  static ProjectIssue _issueFromJson(Map<String, Object?> json) {
    final String? id = _string(json['id']);
    final String? projectId = _string(json['projectId']);
    final String? title = _string(json['title']);
    final IssuePriority? priority = _priorityFromWire(_string(json['priority']));
    final IssueStatus? status = _issueStatusFromWire(_string(json['status']));
    final DateTime? createdAt = _instant(json['createdAt']);
    final int? revision = json['revision'] is int ? json['revision']! as int : null;
    if (id == null ||
        projectId == null ||
        title == null ||
        priority == null ||
        status == null ||
        createdAt == null ||
        revision == null) {
      throw const IssueRepositoryException(
        'The server answered an issue this app could not read.',
      );
    }
    return ProjectIssue(
      id: id,
      projectId: projectId,
      title: title,
      priority: priority,
      status: status,
      createdAt: createdAt,
      // Two identity fields on the wire, one display string here — the same
      // "displayName ?? email ?? id" fallback chain `HttpAuthGateway._Actor`
      // uses for the operator's own identity.
      assignee: _string(json['assigneeEmail']) ?? _string(json['assigneeUserId']) ?? 'Unassigned',
      epicId: _string(json['epicId']),
      summary: _string(json['description']) ?? '',
      blockedReason: _string(json['blockedReason']),
      labels: _stringList(json['labels']),
      dependencies: _stringList(json['dependencies']),
      revision: revision,
    );
  }

  static Epic _epicFromJson(
    Map<String, Object?> json, {
    required List<String> issueIds,
  }) {
    final String? id = _string(json['id']);
    final String? projectId = _string(json['projectId']);
    final String? title = _string(json['title']);
    final IssueStatus? status = _epicStatusFromWire(_string(json['status']));
    final DateTime? createdAt = _instant(json['createdAt']);
    if (id == null ||
        projectId == null ||
        title == null ||
        status == null ||
        createdAt == null) {
      throw const IssueRepositoryException(
        'The server answered an epic this app could not read.',
      );
    }
    return Epic(
      id: id,
      projectId: projectId,
      title: title,
      status: status,
      // No priority column on the gateway's epic — see the class doc.
      createdAt: createdAt,
      summary: _string(json['description']) ?? '',
      // No "blocked" epic status exists on the gateway (`issue_types.py`'s
      // `EPIC_STATUSES`), so a real epic never carries a blocked reason.
      issueIds: issueIds,
    );
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static List<String> _stringList(Object? value) =>
      value is List<Object?> ? value.whereType<String>().toList(growable: false) : const <String>[];

  /// `issue_types.py`'s `ISSUE_STATUSES` (open, in_progress, blocked,
  /// in_review, done, cancelled) folded into #29's four-value
  /// [IssueStatus]. `in_review` becomes "in progress" (still active work,
  /// not blocked, not done) and `cancelled` becomes "done" (both are
  /// terminal — #29 has no "won't do" bucket to route it to instead).
  static IssueStatus? _issueStatusFromWire(String? raw) => switch (raw) {
    'open' => IssueStatus.todo,
    'in_progress' || 'in_review' => IssueStatus.inProgress,
    'blocked' => IssueStatus.blocked,
    'done' || 'cancelled' => IssueStatus.done,
    _ => null,
  };

  static String _issueStatusToWire(IssueStatus status) => switch (status) {
    IssueStatus.todo => 'open',
    IssueStatus.inProgress => 'in_progress',
    IssueStatus.blocked => 'blocked',
    IssueStatus.done => 'done',
  };

  /// `issue_types.py`'s `EPIC_STATUSES` (open, in_progress, done, cancelled
  /// — no `blocked`) folded the same way [_issueStatusFromWire] folds the
  /// issue set; an [Epic.status] never comes back [IssueStatus.blocked] for
  /// a real epic because the gateway has nothing to send that would map to
  /// it.
  static IssueStatus? _epicStatusFromWire(String? raw) => switch (raw) {
    'open' => IssueStatus.todo,
    'in_progress' => IssueStatus.inProgress,
    'done' || 'cancelled' => IssueStatus.done,
    _ => null,
  };

  static String _epicStatusToWire(IssueStatus status) => switch (status) {
    IssueStatus.todo => 'open',
    IssueStatus.inProgress => 'in_progress',
    // The gateway has no epic-blocked state; the nearest honest value is
    // "still open work", not "done".
    IssueStatus.blocked => 'in_progress',
    IssueStatus.done => 'done',
  };

  /// `issue_types.py`'s `ISSUE_PRIORITIES` (low, medium, high, urgent)
  /// renamed to #29's set — `medium` reads as [IssuePriority.normal] and
  /// `urgent` as [IssuePriority.critical], the labels #29's filters and
  /// chips already shipped.
  static IssuePriority? _priorityFromWire(String? raw) => switch (raw) {
    'low' => IssuePriority.low,
    'medium' => IssuePriority.normal,
    'high' => IssuePriority.high,
    'urgent' => IssuePriority.critical,
    _ => null,
  };

  static String _priorityToWire(IssuePriority priority) => switch (priority) {
    IssuePriority.critical => 'urgent',
    IssuePriority.high => 'high',
    IssuePriority.normal => 'medium',
    IssuePriority.low => 'low',
  };
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
