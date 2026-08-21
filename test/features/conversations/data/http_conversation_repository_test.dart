@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/features/conversations/data/http_conversation_repository.dart';
import 'package:codex_bridge_mobile/features/conversations/domain/conversation.dart';
import 'package:codex_bridge_mobile/features/conversations/domain/conversation_message.dart';
import 'package:codex_bridge_mobile/features/conversations/domain/conversation_page.dart';
import 'package:codex_bridge_mobile/features/conversations/domain/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpConversationRepository] against a real, locally bound
/// [HttpServer] — the same discipline `http_auth_gateway_test.dart` uses and
/// for the same reason: plain HTTP to `127.0.0.1` still exercises the actual
/// `dart:io` request/response round trip this class owns (the JSON it sends,
/// the headers it sets, the shapes it accepts or rejects), without a
/// self-signed key this repo's security standards forbid committing even for
/// a test.
///
/// `not validated:` certificate handling. [HttpConversationRepository]
/// installs no `badCertificateCallback` and disables none of [HttpClient]'s
/// defaults, so TLS verification is exactly what `dart:io` does out of the
/// box — the same property [HttpAuthGateway]'s own test leaves unexercised.
void main() {
  Future<HttpServer> serve(
    FutureOr<void> Function(HttpRequest request) handler,
  ) async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen((HttpRequest request) async {
      await handler(request);
    });
    return server;
  }

  Uri serverUri(HttpServer server) =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port);

  Future<String> bodyOf(HttpRequest request) =>
      utf8.decoder.bind(request).join();

  void writeJson(HttpResponse response, int statusCode, Object body) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  Map<String, Object?> conversationJson({
    String id = 'conv-1',
    String projectId = 'proj-1',
    String? title = 'Release planning',
    bool unread = false,
    String? lastActivityAt = '2026-08-21T09:00:00Z',
  }) => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'title': title,
    'context': <Object?>[
      <String, Object?>{'type': 'project', 'id': projectId},
    ],
    'unread': unread,
    'lastActivityAt': lastActivityAt,
    'createdAt': '2026-08-20T10:00:00Z',
    'createdBy': 'esteban@example.com',
  };

  Map<String, Object?> messageJson({
    String id = 'msg-1',
    String conversationId = 'conv-1',
    String body = 'Hello there.',
    List<String> attachments = const <String>[],
  }) => <String, Object?>{
    'id': id,
    'conversationId': conversationId,
    'author': 'esteban@example.com',
    'body': body,
    'attachments': attachments,
    'createdAt': '2026-08-21T09:00:00Z',
  };

  Map<String, Object?> errorJson({
    required String code,
    String message = 'Something went wrong.',
    List<Map<String, Object?>>? details,
  }) => <String, Object?>{
    'code': code,
    'message': message,
    'requestId': 'req-1',
    'retryable': false,
    'details': ?details,
  };

  const String accessToken = 'a-valid-access-token';

  group('loadConversations', () {
    test('parses a page and sends the bearer token', () async {
      String? seenAuth;
      Uri? seenUri;
      final HttpServer server = await serve((HttpRequest request) async {
        seenAuth = request.headers.value(HttpHeaders.authorizationHeader);
        seenUri = request.uri;
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[conversationJson(), conversationJson(id: 'conv-2')],
          'page': <String, Object?>{'hasMore': true, 'nextCursor': 'cursor-2'},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      final ConversationsPage<Conversation> page = await repository.loadConversations(
        server: serverUri(server),
        accessToken: accessToken,
        projectIds: <String>['proj-1', 'proj-2'],
        cursor: 'cursor-1',
        limit: 25,
      );

      expect(seenAuth, 'Bearer $accessToken');
      expect(seenUri?.path, '/api/v1/conversations');
      expect(seenUri?.queryParametersAll['projectId'], <String>['proj-1', 'proj-2']);
      expect(seenUri?.queryParameters['cursor'], 'cursor-1');
      expect(seenUri?.queryParameters['limit'], '25');
      expect(page.items, hasLength(2));
      expect(page.items.first.id, 'conv-1');
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cursor-2');
    });

    test('a 401 is reported with the unauthenticated code, never a throw of a raw exception', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(
          request.response,
          HttpStatus.unauthorized,
          errorJson(code: 'unauthenticated', message: 'Sign in again.'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversations(server: serverUri(server), accessToken: accessToken),
        throwsA(
          isA<ConversationRepositoryException>()
              .having((ConversationRepositoryException e) => e.code, 'code', 'unauthenticated')
              .having((ConversationRepositoryException e) => e.notFound, 'notFound', isFalse)
              .having((ConversationRepositoryException e) => e.message, 'message', 'Sign in again.'),
        ),
      );
    });

    test('a response body that is not JSON is a malformed-response failure, not a crash', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('not json at all {{{');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversations(server: serverUri(server), accessToken: accessToken),
        throwsA(isA<ConversationRepositoryException>()),
      );
    });

    test('a response missing the items/page shape is a malformed-response failure', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{'unexpected': true});
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversations(server: serverUri(server), accessToken: accessToken),
        throwsA(isA<ConversationRepositoryException>()),
      );
    });

    test('a server that accepts the connection and never answers times out', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        // Deliberately never writes to or closes the response — the socket
        // stays open and silent, the scenario a bounded timeout exists for.
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository(
        timeout: Duration(milliseconds: 150),
      );

      await expectLater(
        repository.loadConversations(server: serverUri(server), accessToken: accessToken),
        throwsA(isA<ConversationRepositoryException>()),
      );
    });

    test('a connection that cannot be opened fails closed, not with a raw SocketException', () async {
      final HttpServer deadServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final Uri deadUri = serverUri(deadServer);
      await deadServer.close(force: true);
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversations(server: deadUri, accessToken: accessToken),
        throwsA(isA<ConversationRepositoryException>()),
      );
    });
  });

  group('loadConversation', () {
    test('a conversation outside visibility answers 404, and is reported as notFound', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(
          request.response,
          HttpStatus.notFound,
          errorJson(code: 'not_found', message: 'No such conversation.'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversation(
          server: serverUri(server),
          accessToken: accessToken,
          conversationId: 'hidden-conversation',
        ),
        throwsA(
          isA<ConversationRepositoryException>()
              .having((ConversationRepositoryException e) => e.notFound, 'notFound', isTrue),
        ),
      );
    });

    test('a 403 is reported as permission_denied, and is never conflated with 404', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(
          request.response,
          HttpStatus.forbidden,
          errorJson(code: 'permission_denied', message: 'Not allowed.'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await expectLater(
        repository.loadConversation(
          server: serverUri(server),
          accessToken: accessToken,
          conversationId: 'some-conversation',
        ),
        throwsA(
          isA<ConversationRepositoryException>()
              .having((ConversationRepositoryException e) => e.notFound, 'notFound', isFalse)
              .having((ConversationRepositoryException e) => e.code, 'code', 'permission_denied'),
        ),
      );
    });

    test('a found conversation parses to the exact path requested', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.uri.path, '/api/v1/conversations/conv-42');
        writeJson(request.response, HttpStatus.ok, conversationJson(id: 'conv-42'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      final Conversation conversation = await repository.loadConversation(
        server: serverUri(server),
        accessToken: accessToken,
        conversationId: 'conv-42',
      );

      expect(conversation.id, 'conv-42');
      expect(conversation.context.single.type, ConversationContextType.project);
    });
  });

  group('loadMessages', () {
    test('parses a page in the oldest-first order the server sends, unchanged', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.uri.path, '/api/v1/conversations/conv-1/messages');
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[
            messageJson(id: 'msg-oldest', body: 'first'),
            messageJson(id: 'msg-newest', body: 'second'),
          ],
          'page': <String, Object?>{'hasMore': false},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      final ConversationsPage<ConversationMessage> page = await repository.loadMessages(
        server: serverUri(server),
        accessToken: accessToken,
        conversationId: 'conv-1',
      );

      expect(page.items.map((ConversationMessage m) => m.id), <String>['msg-oldest', 'msg-newest']);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('postMessage', () {
    test('sends the body, attachments and a client-generated Idempotency-Key', () async {
      String? seenKey;
      Map<String, Object?>? seenBody;
      final HttpServer server = await serve((HttpRequest request) async {
        seenKey = request.headers.value('Idempotency-Key');
        seenBody = jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        writeJson(request.response, HttpStatus.created, messageJson(body: 'Ship it.'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      final ConversationMessage message = await repository.postMessage(
        server: serverUri(server),
        accessToken: accessToken,
        conversationId: 'conv-1',
        body: 'Ship it.',
        attachments: <String>['file-1'],
      );

      expect(message.body, 'Ship it.');
      expect(seenBody, <String, Object?>{
        'body': 'Ship it.',
        'attachments': <String>['file-1'],
      });
      expect(seenKey, isNotNull);
      expect(
        seenKey,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
        reason: 'a caller that supplies no idempotencyKey still gets a real, generated one',
      );
    });

    test('two calls with no explicit key generate two different keys', () async {
      final List<String?> seenKeys = <String?>[];
      final HttpServer server = await serve((HttpRequest request) async {
        seenKeys.add(request.headers.value('Idempotency-Key'));
        writeJson(request.response, HttpStatus.created, messageJson());
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      await repository.postMessage(
        server: serverUri(server),
        accessToken: accessToken,
        conversationId: 'conv-1',
        body: 'one',
      );
      await repository.postMessage(
        server: serverUri(server),
        accessToken: accessToken,
        conversationId: 'conv-1',
        body: 'two',
      );

      expect(seenKeys, hasLength(2));
      expect(
        seenKeys[0],
        isNot(seenKeys[1]),
        reason: 'generating a fresh key per call is correct when the caller supplies none — '
            'reuse across retries of the *same* logical send is the caller\'s job',
      );
    });

    test(
      'a retried post with the same Idempotency-Key replays the first response instead of '
      'creating a second message',
      () async {
        int createCount = 0;
        late final Map<String, Object?> firstResponseBody;
        final HttpServer server = await serve((HttpRequest request) async {
          final String? key = request.headers.value('Idempotency-Key');
          expect(key, 'retry-key-123');
          if (createCount == 0) {
            createCount++;
            firstResponseBody = messageJson(id: 'msg-created-once');
            writeJson(request.response, HttpStatus.created, firstResponseBody);
          } else {
            // The real gateway's `idempotency.reserve`/`complete` dance
            // replays the stored response verbatim rather than re-running
            // `store.create_conversation_message` — modeled here by simply
            // answering with the same body a second time and never letting
            // `createCount` advance past 1.
            request.response.headers.set('Idempotent-Replay', 'true');
            writeJson(request.response, HttpStatus.created, firstResponseBody);
          }
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        const HttpConversationRepository repository = HttpConversationRepository();

        final ConversationMessage first = await repository.postMessage(
          server: serverUri(server),
          accessToken: accessToken,
          conversationId: 'conv-1',
          body: 'offline retry test',
          idempotencyKey: 'retry-key-123',
        );
        final ConversationMessage retried = await repository.postMessage(
          server: serverUri(server),
          accessToken: accessToken,
          conversationId: 'conv-1',
          body: 'offline retry test',
          idempotencyKey: 'retry-key-123',
        );

        expect(createCount, 1, reason: 'the server only ever actually created the message once');
        expect(retried.id, first.id);
        expect(retried.createdAt, first.createdAt);
      },
    );
  });

  group('createConversation', () {
    test('sends title and context, and parses the created conversation', () async {
      Map<String, Object?>? seenBody;
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/conversations');
        seenBody = jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        writeJson(request.response, HttpStatus.created, conversationJson(title: 'New thread'));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpConversationRepository repository = HttpConversationRepository();

      final Conversation conversation = await repository.createConversation(
        server: serverUri(server),
        accessToken: accessToken,
        title: 'New thread',
        context: const <ContextReference>[
          ContextReference(type: ConversationContextType.project, id: 'proj-1'),
        ],
      );

      expect(conversation.title, 'New thread');
      expect(seenBody, <String, Object?>{
        'title': 'New thread',
        'context': <Object?>[
          <String, Object?>{'type': 'project', 'id': 'proj-1'},
        ],
      });
    });

    test(
      'a context spanning two projects is rejected 400 mixed_project, surfaced with that code',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(
            request.response,
            HttpStatus.badRequest,
            errorJson(
              code: 'validation_failed',
              message: 'Every context reference must resolve to the same project.',
              details: <Map<String, Object?>>[
                <String, Object?>{
                  'field': '/context',
                  'code': 'mixed_project',
                  'message': 'context references named more than one project.',
                },
              ],
            ),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        const HttpConversationRepository repository = HttpConversationRepository();

        await expectLater(
          repository.createConversation(
            server: serverUri(server),
            accessToken: accessToken,
            context: const <ContextReference>[
              ContextReference(type: ConversationContextType.project, id: 'proj-1'),
              ContextReference(type: ConversationContextType.project, id: 'proj-2'),
            ],
          ),
          throwsA(
            isA<ConversationRepositoryException>()
                .having((ConversationRepositoryException e) => e.code, 'code', 'mixed_project')
                .having((ConversationRepositoryException e) => e.notFound, 'notFound', isFalse),
          ),
        );
      },
    );
  });
}
