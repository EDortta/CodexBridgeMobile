import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/identifiers/idempotency_key.dart';
import '../domain/conversation.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_page.dart';
import '../domain/conversation_repository.dart';

/// Talks to the real conversation endpoints
/// (`EDortta/CodexBridge` issue #10, `gateway/app/api/routes/conversations.py`,
/// `docs/api/codex-bridge.openapi.yaml`'s conversations section).
///
/// Structured like [HttpAuthGateway]: a plain `dart:io` [HttpClient] per
/// call, certificate verification never disabled, and every step — connect,
/// send, read the body — bounded by [timeout] so a server that accepts a
/// socket and stalls cannot hang a screen. `server`/`accessToken` arrive per
/// call rather than injected, the same convention [HttpLiveSessionRepository]
/// uses, because this feature has no session of its own to remember.
///
/// A handful of contract details this class gets right on purpose, each
/// hard-won on the server side (see the route module's own docstring) and
/// worth restating here so a future edit does not quietly undo them:
///
/// - `artifact` is not a context type. There is nothing to special-case for
///   it client-side — [ConversationContextType] simply does not have it.
/// - Message posting sends a client-generated `Idempotency-Key`
///   ([generateIdempotencyKey]) so an offline retry cannot double-post.
/// - `GET .../messages` advances the *caller's own* unread cursor server-side
///   as a side effect of fetching; this class does nothing extra for that —
///   there is no separate "mark as read" call to make.
/// - The conversations list is ordered by `createdAt`/`id`, never
///   `lastActivityAt`; this class does not resort what the server returns.
/// - There is no revision, `ETag`, or `If-Match` anywhere in this feature —
///   unlike [HttpLiveSessionRepository.controlSession], no method here sends
///   one.
class HttpConversationRepository implements ConversationRepository {
  const HttpConversationRepository({
    this.timeout = const Duration(seconds: 10),
  });

  /// Applied to the connection, to sending the request, and to reading each
  /// response body — the same discipline [HttpAuthGateway] applies.
  final Duration timeout;

  static const String _conversationsPath = '/api/v1/conversations';

  @override
  Future<ConversationsPage<Conversation>> loadConversations({
    required Uri server,
    required String accessToken,
    List<String>? projectIds,
    String? cursor,
    int? limit,
  }) async {
    final Map<String, Object?> body = await _send(
      server: server,
      accessToken: accessToken,
      method: 'GET',
      path: _conversationsPath,
      queryParameters: <String, List<String>>{
        if (projectIds != null && projectIds.isNotEmpty) 'projectId': projectIds,
        if (cursor != null) 'cursor': <String>[cursor],
        if (limit != null) 'limit': <String>['$limit'],
      },
      fallback: 'Unable to load conversations.',
    );
    return _pageOf(body, Conversation.fromJson, 'conversations');
  }

  @override
  Future<Conversation> loadConversation({
    required Uri server,
    required String accessToken,
    required String conversationId,
  }) async {
    final Map<String, Object?> body = await _send(
      server: server,
      accessToken: accessToken,
      method: 'GET',
      path: '$_conversationsPath/$conversationId',
      fallback: 'Unable to load this conversation.',
    );
    return _parse(body, Conversation.fromJson, 'conversation');
  }

  @override
  Future<ConversationsPage<ConversationMessage>> loadMessages({
    required Uri server,
    required String accessToken,
    required String conversationId,
    String? cursor,
    int? limit,
  }) async {
    final Map<String, Object?> body = await _send(
      server: server,
      accessToken: accessToken,
      method: 'GET',
      path: '$_conversationsPath/$conversationId/messages',
      queryParameters: <String, List<String>>{
        if (cursor != null) 'cursor': <String>[cursor],
        if (limit != null) 'limit': <String>['$limit'],
      },
      fallback: 'Unable to load this conversation\'s messages.',
    );
    return _pageOf(body, ConversationMessage.fromJson, 'messages');
  }

  @override
  Future<ConversationMessage> postMessage({
    required Uri server,
    required String accessToken,
    required String conversationId,
    required String body,
    List<String>? attachments,
    String? idempotencyKey,
  }) async {
    final Map<String, Object?> response = await _send(
      server: server,
      accessToken: accessToken,
      method: 'POST',
      path: '$_conversationsPath/$conversationId/messages',
      jsonBody: <String, Object?>{'body': body, 'attachments': ?attachments},
      idempotencyKey: idempotencyKey ?? generateIdempotencyKey(),
      fallback: 'Unable to post this message.',
    );
    return _parse(response, ConversationMessage.fromJson, 'message');
  }

  @override
  Future<Conversation> createConversation({
    required Uri server,
    required String accessToken,
    required List<ContextReference> context,
    String? title,
    String? idempotencyKey,
  }) async {
    final Map<String, Object?> response = await _send(
      server: server,
      accessToken: accessToken,
      method: 'POST',
      path: _conversationsPath,
      jsonBody: <String, Object?>{
        'title': ?title,
        'context': context.map((ContextReference ref) => ref.toJson()).toList(growable: false),
      },
      idempotencyKey: idempotencyKey ?? generateIdempotencyKey(),
      fallback: 'Unable to start this conversation.',
    );
    return _parse(response, Conversation.fromJson, 'conversation');
  }

  T _parse<T>(
    Map<String, Object?> json,
    T Function(Map<String, Object?>) fromJson,
    String label,
  ) {
    try {
      return fromJson(json);
    } on FormatException {
      throw ConversationRepositoryException(
        'The server answered an unexpected $label shape.',
      );
    }
  }

  ConversationsPage<T> _pageOf<T>(
    Map<String, Object?> body,
    T Function(Map<String, Object?>) fromJson,
    String label,
  ) {
    final Object? items = body['items'];
    final Object? page = body['page'];
    if (items is! List<Object?> || page is! Map<String, Object?>) {
      throw ConversationRepositoryException(
        'The server answered without a $label page.',
      );
    }
    final Object? hasMoreRaw = page['hasMore'];
    if (hasMoreRaw is! bool) {
      throw ConversationRepositoryException(
        'The server answered without a $label page.',
      );
    }
    final List<T> parsed = items
        .whereType<Map<String, Object?>>()
        .map((Map<String, Object?> item) => _parse(item, fromJson, label))
        .toList(growable: false);
    final Object? nextCursor = page['nextCursor'];
    return ConversationsPage<T>(
      items: parsed,
      hasMore: hasMoreRaw,
      nextCursor: nextCursor is String ? nextCursor : null,
    );
  }

  Future<Map<String, Object?>> _send({
    required Uri server,
    required String accessToken,
    required String method,
    required String path,
    required String fallback,
    Map<String, List<String>>? queryParameters,
    Map<String, Object?>? jsonBody,
    String? idempotencyKey,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final Uri endpoint = _endpoint(server, path, queryParameters);
      final HttpClientRequest request = await (method == 'GET'
              ? client.getUrl(endpoint)
              : client.postUrl(endpoint))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (idempotencyKey != null) {
        request.headers.set('Idempotency-Key', idempotencyKey);
      }
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(jsonBody)));
      }
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final String raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      final Map<String, Object?> decoded = _decodeObject(raw);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFrom(response.statusCode, decoded, fallback: fallback);
      }
      return decoded;
    } on ConversationRepositoryException {
      rethrow;
    } on SocketException {
      throw const ConversationRepositoryException(
        'The Codex Bridge server did not answer.',
      );
    } on HandshakeException {
      throw const ConversationRepositoryException(
        'The secure connection to the server was refused.',
      );
    } on TimeoutException {
      throw const ConversationRepositoryException(
        'The Codex Bridge server took too long to answer.',
      );
    } on Object {
      // Fail closed: anything this class did not anticipate (a malformed
      // URI, an unexpected `dart:io` failure, …) must not escape as a raw
      // exception past this feature's one boundary — the same discipline
      // [HttpLiveSessionRepository] and [HttpAuthGateway] apply.
      throw ConversationRepositoryException(fallback);
    } finally {
      client.close(force: true);
    }
  }

  ConversationRepositoryException _errorFrom(
    int statusCode,
    Map<String, Object?> body, {
    required String fallback,
  }) {
    final String? topCode = body['code'] is String ? body['code']! as String : null;
    String? code = topCode;
    final Object? details = body['details'];
    if (details is List<Object?> && details.isNotEmpty) {
      final Object? first = details.first;
      if (first is Map<String, Object?> && first['code'] is String) {
        // More specific than the envelope's own `code` — e.g. `400
        // validation_failed` at the top with `mixed_project` here, which is
        // what a caller actually wants to branch on.
        code = first['code']! as String;
      }
    }
    final String? message = body['message'] is String ? body['message']! as String : null;
    return ConversationRepositoryException(
      (message != null && message.isNotEmpty) ? message : fallback,
      code: code,
      notFound: statusCode == HttpStatus.notFound,
    );
  }

  static Uri _endpoint(
    Uri server,
    String path,
    Map<String, List<String>>? queryParameters,
  ) {
    final Uri withPath = server.replace(path: '${server.path}$path');
    final Map<String, List<String>> nonEmpty = <String, List<String>>{
      for (final MapEntry<String, List<String>> entry
          in (queryParameters ?? const <String, List<String>>{}).entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
    if (nonEmpty.isEmpty) {
      return withPath;
    }
    // `Uri.replace`'s `queryParameters` accepts `String` or `Iterable<String>`
    // per key, the latter producing a repeated key (`projectId=a&projectId=b`)
    // — exactly the `explode`-style repeated-param encoding
    // `docs/api/codex-bridge.openapi.yaml`'s `projectId` filter expects.
    return withPath.replace(queryParameters: nonEmpty);
  }

  static Map<String, Object?> _decodeObject(String raw) {
    if (raw.isEmpty) {
      return <String, Object?>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const ConversationRepositoryException(
        'The server answered with something that was not JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const ConversationRepositoryException(
        'The server answered an unexpected JSON shape.',
      );
    }
    return decoded;
  }
}
