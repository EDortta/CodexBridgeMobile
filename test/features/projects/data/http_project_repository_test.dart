@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/features/projects/data/http_project_repository.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_health.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_repository.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpProjectRepository] against a real, locally bound
/// [HttpServer] — the same approach `http_auth_gateway_test.dart` uses (and
/// the approach `HttpLiveSessionRepository` shipped without, a gap
/// `docs/napkin-lessons.md` names rather than repeats here). Plain HTTP to
/// `127.0.0.1`, no TLS, exercises the real `dart:io` request/response round
/// trip: the headers this class sets, the JSON shapes it accepts, and —
/// unlike `HttpLiveSessionRepository`'s original version — that every call
/// is actually bounded by a timeout instead of able to hang forever.
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

  void writeJson(HttpResponse response, int statusCode, Object body) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  Uri serverUri(HttpServer server) =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port);

  Map<String, Object?> projectJson({
    String id = 'codex-bridge',
    String name = 'Codex Bridge',
    bool enabled = true,
    String health = 'ok',
    int pendingDecisions = 0,
    int activeMissions = 0,
  }) => <String, Object?>{
    'id': id,
    'name': name,
    'enabled': enabled,
    'health': health,
    'pendingDecisions': pendingDecisions,
    'activeMissions': activeMissions,
    'totalSessions': 4,
    'lastActivityAt': '2026-08-20T12:00:00Z',
  };

  group('loadProjects', () {
    test('a successful response maps every project, health included', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/projects');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer an-access-token',
        );
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[
            projectJson(id: 'p-ok', health: 'ok'),
            projectJson(id: 'p-ok-pending', health: 'ok', pendingDecisions: 2),
            projectJson(id: 'p-degraded', health: 'degraded'),
            projectJson(id: 'p-unknown', health: 'unknown'),
            projectJson(id: 'p-disabled', enabled: false, health: 'disabled'),
          ],
          'page': <String, Object?>{'hasMore': false, 'nextCursor': null},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      final List<ProjectSummary> projects = await repository.loadProjects(
        server: serverUri(server),
        accessToken: 'an-access-token',
      );

      expect(projects, hasLength(5));
      final Map<String, ProjectSummary> byId = <String, ProjectSummary>{
        for (final ProjectSummary p in projects) p.id: p,
      };
      expect(byId['p-ok']!.health, ProjectHealth.active);
      expect(byId['p-ok']!.attentionSummary, isNull);
      expect(byId['p-ok-pending']!.health, ProjectHealth.pendingDecision);
      expect(
        byId['p-ok-pending']!.attentionSummary,
        '2 decisions waiting your review',
      );
      expect(byId['p-degraded']!.health, ProjectHealth.unhealthy);
      expect(byId['p-unknown']!.health, ProjectHealth.offline);
      expect(byId['p-disabled']!.health, ProjectHealth.offline);
      expect(byId['p-disabled']!.attentionSummary, 'Disabled in the registry');
    });

    test(
      'a 401 fails closed with a session-expired message, not a generic one',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(request.response, HttpStatus.unauthorized, <String, Object?>{
            'code': 'unauthenticated',
            'message': 'The access token is expired.',
            'requestId': 'req-1',
            'retryable': false,
          });
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        const HttpProjectRepository repository = HttpProjectRepository();

        await expectLater(
          repository.loadProjects(
            server: serverUri(server),
            accessToken: 'an-expired-token',
          ),
          throwsA(
            isA<ProjectRepositoryException>().having(
              (ProjectRepositoryException e) => e.message,
              'message',
              'Your session is no longer valid. Sign in again.',
            ),
          ),
        );
      },
    );

    test('a non-JSON body fails closed instead of throwing uncaught', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('<html>not json</html>');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      await expectLater(
        repository.loadProjects(
          server: serverUri(server),
          accessToken: 'a-token',
        ),
        throwsA(isA<ProjectRepositoryException>()),
      );
    });

    test('a shape without an items list fails closed', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'projects': <Object?>[],
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      await expectLater(
        repository.loadProjects(
          server: serverUri(server),
          accessToken: 'a-token',
        ),
        throwsA(isA<ProjectRepositoryException>()),
      );
    });

    test(
      'a server that accepts the connection and never answers times out',
      () async {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        // Accept the connection but never write a response — a stalled
        // server, not a refused one. addTearDown closes it after the test,
        // regardless of outcome.
        server.listen((HttpRequest request) {});
        addTearDown(() => server.close(force: true));
        const HttpProjectRepository repository = HttpProjectRepository(
          timeout: Duration(milliseconds: 100),
        );

        await expectLater(
          repository.loadProjects(
            server: serverUri(server),
            accessToken: 'a-token',
          ),
          throwsA(isA<ProjectRepositoryException>()),
        );
      },
    );

    test('a connection that cannot be opened fails closed', () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final int deadPort = server.port;
      await server.close(force: true);
      const HttpProjectRepository repository = HttpProjectRepository();

      await expectLater(
        repository.loadProjects(
          server: Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: deadPort,
          ),
          accessToken: 'a-token',
        ),
        throwsA(isA<ProjectRepositoryException>()),
      );
    });
  });

  group('loadProject', () {
    test('a successful response returns the project', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.uri.path, '/api/v1/projects/codex-bridge');
        writeJson(
          request.response,
          HttpStatus.ok,
          projectJson(id: 'codex-bridge', health: 'ok'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      final ProjectSummary? project = await repository.loadProject(
        server: serverUri(server),
        accessToken: 'a-token',
        id: 'codex-bridge',
      );

      expect(project, isNotNull);
      expect(project!.id, 'codex-bridge');
      expect(project.health, ProjectHealth.active);
    });

    test(
      'a 404 reports "not found" as null — the same answer the backend '
      'gives for a project outside the caller\'s visible scope, never a '
      'thrown error',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(request.response, HttpStatus.notFound, <String, Object?>{
            'code': 'not_found',
            'message': 'No such project.',
            'requestId': 'req-1',
            'retryable': false,
          });
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        const HttpProjectRepository repository = HttpProjectRepository();

        final ProjectSummary? project = await repository.loadProject(
          server: serverUri(server),
          accessToken: 'a-token',
          id: 'someone-elses-project',
        );

        expect(
          project,
          isNull,
          reason:
              'a 404 must read as "no such project", not throw a generic '
              'ProjectRepositoryException the way any other non-200 does',
        );
      },
    );

    test('a 401 fails closed with a session-expired message', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      await expectLater(
        repository.loadProject(
          server: serverUri(server),
          accessToken: 'an-expired-token',
          id: 'codex-bridge',
        ),
        throwsA(
          isA<ProjectRepositoryException>().having(
            (ProjectRepositoryException e) => e.message,
            'message',
            'Your session is no longer valid. Sign in again.',
          ),
        ),
      );
    });

    test('a malformed project shape fails closed', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'id': 'codex-bridge',
          // 'name' and 'health' are missing.
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      const HttpProjectRepository repository = HttpProjectRepository();

      await expectLater(
        repository.loadProject(
          server: serverUri(server),
          accessToken: 'a-token',
          id: 'codex-bridge',
        ),
        throwsA(isA<ProjectRepositoryException>()),
      );
    });
  });

  group('projectHealthFromBackend', () {
    test('ok with no pending decisions is active, with no attention text', () {
      final (ProjectHealth health, String? attention) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'ok',
        pendingDecisions: 0,
      );
      expect(health, ProjectHealth.active);
      expect(attention, isNull);
    });

    test('ok with pending decisions surfaces the count, singular and plural', () {
      final (ProjectHealth singular, String? singularText) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'ok',
        pendingDecisions: 1,
      );
      final (ProjectHealth plural, String? pluralText) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'ok',
        pendingDecisions: 3,
      );
      expect(singular, ProjectHealth.pendingDecision);
      expect(singularText, '1 decision waiting your review');
      expect(plural, ProjectHealth.pendingDecision);
      expect(pluralText, '3 decisions waiting your review');
    });

    test('degraded is unhealthy', () {
      final (ProjectHealth health, String? attention) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'degraded',
        pendingDecisions: 0,
      );
      expect(health, ProjectHealth.unhealthy);
      expect(attention, 'No live executor connected');
    });

    test('unknown is offline', () {
      final (ProjectHealth health, String? attention) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'unknown',
        pendingDecisions: 0,
      );
      expect(health, ProjectHealth.offline);
      expect(attention, 'No executor assigned to this project');
    });

    test('a disabled project is offline regardless of the health value', () {
      final (ProjectHealth health, String? attention) = projectHealthFromBackend(
        enabled: false,
        backendHealth: 'ok',
        pendingDecisions: 5,
      );
      expect(health, ProjectHealth.offline);
      expect(attention, 'Disabled in the registry');
    });

    test('an unrecognized backend health fails closed as unhealthy', () {
      final (ProjectHealth health, String? attention) = projectHealthFromBackend(
        enabled: true,
        backendHealth: 'some-future-value',
        pendingDecisions: 0,
      );
      expect(health, ProjectHealth.unhealthy);
      expect(attention, 'Unrecognized health: some-future-value');
    });
  });
}
