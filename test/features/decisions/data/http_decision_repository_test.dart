@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/features/decisions/data/http_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_audit_event.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_risk.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_state.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpDecisionRepository] against a real, locally bound
/// [HttpServer] — no TLS, so no self-signed key to commit
/// (`security-standards.md` §1), same reasoning `HttpAuthGatewayTest`
/// documents. Plain HTTP to `127.0.0.1` still exercises the actual `dart:io`
/// request/response round trip this class owns: the JSON it sends, the
/// headers it sets (`Authorization`, `If-Match`), and the shapes it accepts
/// or rejects from a real socket.
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

  Future<String> bodyOf(HttpRequest request) =>
      utf8.decoder.bind(request).join();

  void writeJson(HttpResponse response, int statusCode, Object body) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  Map<String, Object?> errorBody({
    required String code,
    required String message,
  }) => <String, Object?>{
    'code': code,
    'message': message,
    'requestId': 'req-1',
    'retryable': false,
  };

  Map<String, Object?> decisionJson({
    String id = 'dec-1',
    String projectId = 'proj-1',
    String executorId = 'exec-1',
    String request = 'Deploy the hotfix',
    String mode = 'default',
    String state = 'pending',
    Object? risk = 'sensitive',
    Object? urgency = 'high',
    int revision = 5,
    Object? requestedBy = 'alice@example.com',
    Object? rationale,
    String createdAt = '2026-08-20T09:00:00Z',
    String deadline = '2026-08-22T09:00:00Z',
    Object? decidedAt,
  }) => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'executorId': executorId,
    'request': request,
    'mode': mode,
    'state': state,
    'risk': risk,
    'urgency': urgency,
    'revision': revision,
    'requestedBy': requestedBy,
    'rationale': rationale,
    'createdAt': createdAt,
    'deadline': deadline,
    'decidedAt': decidedAt,
  };

  HttpDecisionRepository repositoryFor(
    HttpServer server, {
    String accessToken = 'token-1',
    Duration timeout = const Duration(seconds: 5),
  }) => HttpDecisionRepository(
    () async => GatewayContext(
      server: Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      ),
      accessToken: accessToken,
    ),
    timeout: timeout,
  );

  group('loadDecisions', () {
    test('maps the server\'s decision list', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/decisions');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer token-1',
        );
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[
            decisionJson(requestedBy: null, urgency: 'high', risk: 'sensitive'),
          ],
          'page': <String, Object?>{'hasMore': false},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final List<Decision> decisions = await repositoryFor(
        server,
      ).loadDecisions();

      expect(decisions, hasLength(1));
      final Decision decision = decisions.single;
      expect(decision.id, 'dec-1');
      expect(decision.projectId, 'proj-1');
      expect(decision.title, 'Deploy the hotfix');
      expect(
        decision.requestedBy,
        'Unknown',
        reason: 'requestedBy was null in the response',
      );
      expect(decision.requestedAt, DateTime.parse('2026-08-20T09:00:00Z'));
      expect(decision.urgency, DecisionUrgency.high);
      expect(decision.risk, DecisionRisk.high);
      expect(decision.state, DecisionState.pending);
      expect(decision.deadline, DateTime.parse('2026-08-22T09:00:00Z'));
      expect(
        decision.auditTrail,
        isEmpty,
        reason: 'nothing to synthesize while still pending',
      );
    });

    test('a 401 answers with the server\'s message', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(
          request.response,
          HttpStatus.unauthorized,
          errorBody(code: 'unauthenticated', message: 'Token expired.'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadDecisions(),
        throwsA(
          isA<DecisionRepositoryException>().having(
            (DecisionRepositoryException e) => e.message,
            'message',
            'Token expired.',
          ),
        ),
      );
    });

    test('no server or session fails closed without a network call', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('no context available must not reach the network');
      });
      addTearDown(() => server.close(force: true));
      final HttpDecisionRepository repository = HttpDecisionRepository(
        () async => null,
      );

      await expectLater(
        repository.loadDecisions(),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });

    test('a connection that cannot be opened is reported, not thrown raw', () async {
      final HttpServer deadServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final int deadPort = deadServer.port;
      await deadServer.close(force: true);
      final HttpDecisionRepository repository = HttpDecisionRepository(
        () async => GatewayContext(
          server: Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: deadPort,
          ),
          accessToken: 'token-1',
        ),
      );

      await expectLater(
        repository.loadDecisions(),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });
  });

  group('loadDecision', () {
    test(
      'a resolved decision gets one synthesized resolution-history entry',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(
              state: 'approved',
              rationale: 'Looks safe to ship.',
              decidedAt: '2026-08-21T10:00:00Z',
            ),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final Decision decision = await repositoryFor(
          server,
        ).loadDecision('dec-1');

        expect(decision.state, DecisionState.approved);
        expect(decision.auditTrail, hasLength(1));
        final DecisionAuditEvent event = decision.auditTrail.single;
        expect(event.action, DecisionAuditAction.approved);
        expect(event.actor, 'Unknown actor');
        expect(event.comment, 'Looks safe to ship.');
        expect(event.occurredAt, DateTime.parse('2026-08-21T10:00:00Z'));
      },
    );

    test(
      'a decision outside the caller\'s scope answers 404, not 403',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(
            request.response,
            HttpStatus.notFound,
            errorBody(code: 'not_found', message: 'No such decision.'),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repositoryFor(server).loadDecision('outside-scope'),
          throwsA(
            isA<DecisionNotFoundException>().having(
              (DecisionNotFoundException e) => e.decisionId,
              'decisionId',
              'outside-scope',
            ),
          ),
        );
      },
    );

    test('a non-JSON body is reported, not thrown raw', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('<html>not json</html>');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadDecision('dec-1'),
        throwsA(
          isA<DecisionRepositoryException>().having(
            (DecisionRepositoryException e) => e.message,
            'message',
            contains('not JSON'),
          ),
        ),
      );
    });

    test('a decision missing a required field is reported, not crashed on', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        final Map<String, Object?> body = decisionJson()..remove('deadline');
        writeJson(request.response, HttpStatus.ok, body);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadDecision('dec-1'),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });

    test('a slow server times out instead of hanging the caller', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        // Never writes a response — the client's own bounded timeout, not a
        // delayed-then-abandoned write on this side, is what this test
        // exercises.
        await Completer<void>().future;
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(
          server,
          timeout: const Duration(milliseconds: 100),
        ).loadDecision('dec-1'),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });
  });

  group('approve', () {
    test('reads the current revision, then sends it as If-Match with confirm', () async {
      int getCount = 0;
      int postCount = 0;
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET' &&
            request.uri.path == '/api/v1/decisions/dec-1') {
          getCount++;
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/decisions/dec-1/approve') {
          postCount++;
          expect(request.headers.value(HttpHeaders.ifMatchHeader), '"5"');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer token-1',
          );
          final Map<String, Object?> body =
              jsonDecode(await bodyOf(request)) as Map<String, Object?>;
          expect(body['confirm'], isTrue);
          expect(body['reason'], 'Looks fine');
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(
              revision: 6,
              state: 'approved',
              rationale: 'Looks fine',
              decidedAt: '2026-08-21T11:00:00Z',
            ),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Decision result = await repositoryFor(
        server,
      ).approve('dec-1', comment: 'Looks fine');

      expect(result.state, DecisionState.approved);
      expect(getCount, 1);
      expect(postCount, 1);
    });

    test('omits reason when no comment is given, but always confirms', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        final Map<String, Object?> body =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(body.containsKey('reason'), isFalse);
        expect(body['confirm'], isTrue);
        writeJson(
          request.response,
          HttpStatus.ok,
          decisionJson(revision: 6, state: 'approved'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Decision result = await repositoryFor(server).approve('dec-1');

      expect(result.state, DecisionState.approved);
    });

    test('a 412 stale revision is a conflict, never retried', () async {
      int postCount = 0;
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        postCount++;
        writeJson(
          request.response,
          HttpStatus.preconditionFailed,
          errorBody(
            code: 'stale_write',
            message: 'This entity changed since you read it.',
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).approve('dec-1', comment: 'ok'),
        throwsA(
          isA<DecisionConflictException>().having(
            (DecisionConflictException e) => e.message,
            'message',
            'This entity changed since you read it.',
          ),
        ),
      );
      expect(postCount, 1, reason: 'a stale write is surfaced, not retried');
    });

    test('a connection lost mid-resolve is reported, not left hanging', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        // Never writes a response to the POST — the client's own bounded
        // timeout is what this test exercises.
        await Completer<void>().future;
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(
          server,
          timeout: const Duration(milliseconds: 100),
        ).approve('dec-1', comment: 'ok'),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });
  });

  group('reject', () {
    test('an empty justification is refused before any request is sent', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('an empty justification must not reach the network');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).reject('dec-1', justification: '   '),
        throwsArgumentError,
      );
    });

    test('a successful rejection sends the justification as reason', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        expect(request.uri.path, '/api/v1/decisions/dec-1/reject');
        expect(request.headers.value(HttpHeaders.ifMatchHeader), '"5"');
        final Map<String, Object?> body =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(body['reason'], 'Not ready for this environment.');
        writeJson(
          request.response,
          HttpStatus.ok,
          decisionJson(
            revision: 6,
            state: 'rejected',
            rationale: 'Not ready for this environment.',
            decidedAt: '2026-08-21T11:05:00Z',
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Decision result = await repositoryFor(server).reject(
        'dec-1',
        justification: 'Not ready for this environment.',
      );

      expect(result.state, DecisionState.rejected);
      expect(result.auditTrail.single.action, DecisionAuditAction.rejected);
    });
  });

  group('requestRevision', () {
    test('an empty comment is refused before any request is sent', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('an empty comment must not reach the network');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).requestRevision('dec-1', comment: ''),
        throwsArgumentError,
      );
    });

    test('a successful revision request sends the comment as reason', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(
            request.response,
            HttpStatus.ok,
            decisionJson(revision: 5, state: 'pending'),
          );
          await request.response.close();
          return;
        }
        expect(request.uri.path, '/api/v1/decisions/dec-1/request-revision');
        final Map<String, Object?> body =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(body['reason'], 'Add a rollback plan.');
        writeJson(
          request.response,
          HttpStatus.ok,
          decisionJson(revision: 6, state: 'revision_requested'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Decision result = await repositoryFor(
        server,
      ).requestRevision('dec-1', comment: 'Add a rollback plan.');

      expect(result.state, DecisionState.needsRevision);
    });

    test(
      'a 409 already-resolved conflict is reported the same way a stale '
      'revision is, never retried',
      () async {
        int postCount = 0;
        final HttpServer server = await serve((HttpRequest request) async {
          if (request.method == 'GET') {
            writeJson(
              request.response,
              HttpStatus.ok,
              decisionJson(revision: 5, state: 'pending'),
            );
            await request.response.close();
            return;
          }
          postCount++;
          writeJson(
            request.response,
            HttpStatus.conflict,
            errorBody(
              code: 'conflict',
              message: 'A decision in state "approved" cannot be resolved again.',
            ),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repositoryFor(
            server,
          ).requestRevision('dec-1', comment: 'Add a rollback plan.'),
          throwsA(isA<DecisionConflictException>()),
        );
        expect(postCount, 1);
      },
    );
  });

  group('discuss', () {
    test('an empty comment is refused before any request is sent', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('an empty comment must not reach the network');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).discuss('dec-1', comment: ''),
        throwsArgumentError,
      );
    });

    test('a non-empty comment still fails: no server endpoint exists', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('discuss must not reach the network — there is nowhere to send it');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).discuss('dec-1', comment: 'A comment.'),
        throwsA(isA<DecisionRepositoryException>()),
      );
    });
  });
}
