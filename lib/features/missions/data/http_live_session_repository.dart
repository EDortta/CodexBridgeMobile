import 'dart:convert';
import 'dart:io';

import '../domain/live_session.dart';
import '../domain/live_session_explanation.dart';
import '../domain/live_session_log_entry.dart';
import '../domain/live_session_repository.dart';

class HttpLiveSessionRepository implements LiveSessionRepository {
  const HttpLiveSessionRepository();

  @override
  Future<List<LiveSession>> loadSessions({
    required Uri server,
    required String accessToken,
  }) async {
    final Map<String, Object?> body = await _getJsonObject(
      server: server,
      accessToken: accessToken,
      path: '/api/v1/sessions',
      fallback: 'Unable to load sessions.',
    );
    final Object? items = body['items'];
    if (items is! List<Object?>) {
      throw const LiveSessionRepositoryException(
        'The server answered without a sessions list.',
      );
    }
    return items
        .whereType<Map<String, Object?>>()
        .map(LiveSession.fromJson)
        .toList(growable: false);
  }

  @override
  Future<LiveSession> loadSessionDetail({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async {
    final Map<String, Object?> body = await _getJsonObject(
      server: server,
      accessToken: accessToken,
      path: '/api/v1/sessions/$sessionId',
      fallback: 'Unable to load this session.',
    );
    return LiveSession.fromJson(body);
  }

  @override
  Future<List<LiveSessionLogEntry>> loadSessionLogs({
    required Uri server,
    required String accessToken,
    required String sessionId,
    int offset = 0,
    int limit = 200,
  }) async {
    final Uri endpoint = _endpoint(
      server,
      '/api/v1/sessions/$sessionId/logs',
    ).replace(
      queryParameters: <String, String>{
        'offset': '$offset',
        'limit': '$limit',
      },
    );
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(endpoint);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close();
      final Map<String, Object?> body = await _jsonObject(response);
      if (response.statusCode != HttpStatus.ok) {
        throw LiveSessionRepositoryException(
          _messageOf(body, fallback: 'Unable to load the session logs.'),
        );
      }
      final Object? items = body['items'];
      if (items is! List<Object?>) {
        throw const LiveSessionRepositoryException(
          'The server answered without log lines.',
        );
      }
      return items
          .whereType<Map<String, Object?>>()
          .map(LiveSessionLogEntry.fromJson)
          .toList(growable: false);
    } on SocketException {
      throw const LiveSessionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const LiveSessionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.postUrl(
        _endpoint(server, '/api/v1/sessions/$sessionId/${action.pathSegment}'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.ifMatchHeader, '"$revision"');
      final HttpClientResponse response = await request.close();
      final Map<String, Object?> body = await _jsonObject(response);
      if (response.statusCode != HttpStatus.ok) {
        throw LiveSessionRepositoryException(
          _messageOf(
            body,
            fallback: 'The server refused to ${action.pathSegment} this session.',
          ),
        );
      }
      return LiveSession.fromJson(body);
    } on SocketException {
      throw const LiveSessionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const LiveSessionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<LiveSessionErrorExplanation> explainError({
    required Uri server,
    required String accessToken,
    required String sessionId,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.postUrl(
        _endpoint(server, '/api/v1/sessions/$sessionId/explain-error'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close();
      final Map<String, Object?> body = await _jsonObject(response);
      if (response.statusCode != HttpStatus.ok) {
        throw LiveSessionRepositoryException(
          _messageOf(body, fallback: 'Unable to explain this session.'),
        );
      }
      return LiveSessionErrorExplanation.fromJson(body);
    } on SocketException {
      throw const LiveSessionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const LiveSessionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Uri _endpoint(Uri server, String path) =>
      server.replace(path: '${server.path}$path');

  Future<Map<String, Object?>> _getJsonObject({
    required Uri server,
    required String accessToken,
    required String path,
    required String fallback,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(_endpoint(server, path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close();
      final Map<String, Object?> body = await _jsonObject(response);
      if (response.statusCode != HttpStatus.ok) {
        throw LiveSessionRepositoryException(
          _messageOf(body, fallback: fallback),
        );
      }
      return body;
    } on SocketException {
      throw const LiveSessionRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const LiveSessionRepositoryException(
        'The secure connection to the server was refused.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, Object?>> _jsonObject(
    HttpClientResponse response,
  ) async {
    final String raw = await utf8.decoder.bind(response).join();
    final Object? decoded;
    try {
      decoded = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
    } on FormatException {
      // A proxy or intermediary answering with a non-JSON error page (a 502
      // HTML page, for instance) used to throw uncaught here — every call
      // site's own try/catch only names SocketException/HandshakeException,
      // so this escaped the same way an unhandled state used to elsewhere in
      // this feature (council 2026-08-18, "the sweep skeptic").
      throw const LiveSessionRepositoryException(
        'The server answered with something that was not JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const LiveSessionRepositoryException(
        'The server answered an unexpected JSON shape.',
      );
    }
    return decoded;
  }

  static String _messageOf(Map<String, Object?> body, {required String fallback}) {
    final String? message =
        body['message'] is String ? body['message']! as String : null;
    return (message != null && message.isNotEmpty) ? message : fallback;
  }
}
