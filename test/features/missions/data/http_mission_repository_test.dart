@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/features/missions/data/http_mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_explanation.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_risk.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_stage.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpMissionRepository] against a real, locally bound
/// [HttpServer] — no TLS, so no self-signed key to commit
/// (`security-standards.md` §1), same reasoning `HttpAuthGatewayTest` and
/// `HttpLiveSessionRepositoryTest` document. Plain HTTP to `127.0.0.1` still
/// exercises the actual `dart:io` request/response round trip this class
/// owns.
///
/// `not validated:` certificate handling — same carve-out
/// `HttpAuthGatewayTest` documents, for the same reason.
void main() {
  Future<HttpServer> serve(
    FutureOr<void> Function(HttpRequest request) handler,
  ) async {
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      await handler(request);
    });
    return server;
  }

  void writeJson(HttpResponse response, int statusCode, Object body, {String? etag}) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    if (etag != null) {
      response.headers.set(HttpHeaders.etagHeader, etag);
    }
    response.write(jsonEncode(body));
  }

  HttpMissionRepository repositoryFor(HttpServer server) => HttpMissionRepository(
    () async => (
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port),
      'a-valid-access-token',
    ),
    timeout: const Duration(seconds: 2),
  );

  Map<String, Object?> missionDto({
    String id = 'mission-1',
    String projectId = 'codex-bridge',
    String assignedAgent = 'claude',
    String objective = 'Ship the thing.',
    String state = 'running',
    String stage = 'active',
    String risk = 'controlled_write',
    bool blocked = false,
    Map<String, Object?>? blockedReason,
    int revision = 7,
    String createdAt = '2026-08-20T10:00:00Z',
    String? startedAt = '2026-08-20T10:01:00Z',
    String? lastError,
  }) => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'assignedAgent': assignedAgent,
    'objective': objective,
    'mode': 'code',
    'state': state,
    'stage': stage,
    'risk': risk,
    'blocked': blocked,
    'blockedReason': blockedReason,
    'priority': 'normal',
    'revision': revision,
    'createdAt': createdAt,
    'startedAt': startedAt,
    'completedAt': null,
    'expiresAt': '2026-08-21T10:00:00Z',
    'approvalState': null,
    'requestedBy': 'esteban',
    'lastError': lastError,
  };

  group('loadMissions', () {
    test('parses a page of missions', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/missions');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer a-valid-access-token',
        );
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[
            missionDto(id: 'mission-1'),
            missionDto(id: 'mission-2', state: 'queued', stage: 'pending', risk: 'read'),
          ],
          'page': <String, Object?>{'hasMore': false, 'nextCursor': null},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final List<Mission> missions = await repositoryFor(server).loadMissions();

      expect(missions, hasLength(2));
      expect(missions[0].id, 'mission-1');
      expect(missions[0].projectId, 'codex-bridge');
      expect(missions[0].owner, 'claude');
      expect(missions[0].objective, 'Ship the thing.');
      expect(missions[0].state, MissionState.active);
      expect(missions[0].stage, MissionStage.implementation);
      expect(missions[0].risk, MissionRisk.medium);
      expect(missions[1].state, MissionState.active, reason: 'queued is not terminal or blocked');
      expect(missions[1].stage, MissionStage.planning);
      expect(missions[1].risk, MissionRisk.low);
    });

    test('a blocked mission carries its blockedReason summary', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[
            missionDto(
              state: 'awaiting_approval',
              blocked: true,
              blockedReason: <String, Object?>{
                'code': 'awaiting_approval',
                'summary': 'Held for approval before it may proceed.',
              },
            ),
          ],
          'page': <String, Object?>{'hasMore': false, 'nextCursor': null},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final List<Mission> missions = await repositoryFor(server).loadMissions();

      expect(missions.single.state, MissionState.blocked);
      expect(missions.single.blockedReason, 'Held for approval before it may proceed.');
      expect(missions.single.needsIntervention, isTrue);
    });

    test('a completed mission reports full progress', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'items': <Object?>[missionDto(state: 'completed', stage: 'done')],
          'page': <String, Object?>{'hasMore': false, 'nextCursor': null},
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final List<Mission> missions = await repositoryFor(server).loadMissions();

      expect(missions.single.progress, 1.0);
      expect(missions.single.state, MissionState.completed);
    });

    test('a 401 is reported as an authentication failure', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.unauthorized, <String, Object?>{
          'code': 'unauthenticated',
          'message': 'The credential is not valid.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadMissions(),
        throwsA(
          isA<MissionRepositoryException>().having(
            (MissionRepositoryException e) => e.message,
            'message',
            'The credential is not valid.',
          ),
        ),
      );
    });

    test('a connection that cannot be opened times out cleanly', () async {
      final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final int deadPort = server.port;
      await server.close(force: true);
      final HttpMissionRepository repository = HttpMissionRepository(
        () async => (
          Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: deadPort),
          'token',
        ),
        timeout: const Duration(milliseconds: 500),
      );

      await expectLater(repository.loadMissions(), throwsA(isA<MissionRepositoryException>()));
    });

    test('a server that never answers is bounded by the timeout, not left hanging', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        // Never respond — the client must give up on its own.
      });
      addTearDown(() => server.close(force: true));
      final HttpMissionRepository repository = HttpMissionRepository(
        () async => (
          Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port),
          'token',
        ),
        timeout: const Duration(milliseconds: 300),
      );

      await expectLater(repository.loadMissions(), throwsA(isA<MissionRepositoryException>()));
    });

    test('a non-JSON response body is a malformed-response failure, not a crash', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html>not json</html>');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadMissions(),
        throwsA(isA<MissionRepositoryException>()),
      );
    });

    test('an unexpected JSON shape (no items list) is reported, not thrown raw', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.ok, <String, Object?>{'unexpected': true});
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadMissions(),
        throwsA(isA<MissionRepositoryException>()),
      );
    });

    test('no server/session configured fails closed without a network call', () async {
      final HttpMissionRepository repository = HttpMissionRepository(() async => null);

      await expectLater(
        repository.loadMissions(),
        throwsA(isA<MissionRepositoryException>()),
      );
    });
  });

  group('loadMission', () {
    test('combines the detail and timeline endpoints into one Mission', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.uri.path == '/api/v1/missions/mission-1') {
          writeJson(request.response, HttpStatus.ok, missionDto(id: 'mission-1'));
          await request.response.close();
          return;
        }
        if (request.uri.path == '/api/v1/missions/mission-1/timeline') {
          writeJson(request.response, HttpStatus.ok, <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'type': 'task.created',
                'at': '2026-08-20T10:00:00Z',
                'state': null,
                'actor': null,
                'summary': 'Mission created.',
              },
              <String, Object?>{
                'type': 'task.state_changed',
                'at': '2026-08-20T10:05:00Z',
                'state': 'running',
                'actor': 'esteban',
                'summary': 'State changed to running.',
              },
            ],
            'page': <String, Object?>{'hasMore': false, 'nextCursor': null},
          });
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Mission mission = await repositoryFor(server).loadMission('mission-1');

      expect(mission.id, 'mission-1');
      expect(mission.timeline, hasLength(2));
      expect(mission.timeline[0].description, 'Mission created.');
      expect(mission.timeline[1].actor, 'esteban');
      expect(mission.timeline[1].occurredAt, DateTime.parse('2026-08-20T10:05:00Z'));
    });

    test('a 404 on the mission itself is not-found, never a raw throw', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.notFound, <String, Object?>{
          'code': 'not_found',
          'message': 'No such mission.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).loadMission('does-not-exist'),
        throwsA(isA<MissionNotFoundException>()),
      );
    });

    test(
      'a mission outside the caller\'s visible projects answers 404, and the '
      'client surfaces the same not-found — never a distinct 403 path',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          // The gateway's own contract: a hidden mission answers 404, never
          // 403, so probing cannot map what the caller cannot see. The
          // client has no special-casing for 403 here at all — it must
          // treat this exactly like "does not exist".
          writeJson(request.response, HttpStatus.notFound, <String, Object?>{
            'code': 'not_found',
            'message': 'No such mission.',
            'requestId': 'req-1',
            'retryable': false,
          });
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repositoryFor(server).loadMission('out-of-scope-mission'),
          throwsA(isA<MissionNotFoundException>()),
        );
      },
    );
  });

  group('pause / resume', () {
    test('pause fails closed with no network call — the gateway has no pause endpoint', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('pause must never reach the network: the gateway has no pause endpoint');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).pause('mission-1'),
        throwsA(isA<MissionControlNotAllowedException>()),
      );
    });

    test('resume fails closed with no network call — the gateway has no resume endpoint', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('resume must never reach the network: the gateway has no resume endpoint');
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).resume('mission-1'),
        throwsA(isA<MissionControlNotAllowedException>()),
      );
    });
  });

  group('cancel', () {
    test('rejects an empty reason before any request is sent', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        fail('an invalid local precondition must never reach the network');
      });
      addTearDown(() => server.close(force: true));

      expect(
        () => repositoryFor(server).cancel('mission-1', reason: '   '),
        throwsArgumentError,
      );
    });

    test(
      'reads the mission fresh for its revision, then sends If-Match and returns the result',
      () async {
        int detailCalls = 0;
        final HttpServer server = await serve((HttpRequest request) async {
          if (request.method == 'GET' && request.uri.path == '/api/v1/missions/mission-1') {
            detailCalls += 1;
            writeJson(request.response, HttpStatus.ok, missionDto(revision: 9));
            await request.response.close();
            return;
          }
          if (request.method == 'POST' &&
              request.uri.path == '/api/v1/missions/mission-1/cancel') {
            expect(request.headers.value(HttpHeaders.ifMatchHeader), '"9"');
            writeJson(
              request.response,
              HttpStatus.ok,
              missionDto(state: 'cancelled', stage: 'done', revision: 10)
                ..['executorNotified'] = true,
            );
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final Mission mission = await repositoryFor(
          server,
        ).cancel('mission-1', reason: 'No longer needed.');

        expect(detailCalls, 1);
        expect(mission.state, MissionState.cancelled);
      },
    );

    test('a 409 (not cancellable in this state) is a control-not-allowed failure', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'GET') {
          writeJson(request.response, HttpStatus.ok, missionDto(state: 'completed', revision: 3));
          await request.response.close();
          return;
        }
        writeJson(request.response, HttpStatus.conflict, <String, Object?>{
          'code': 'conflict',
          'message': "A mission in state 'completed' cannot be cancelled.",
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).cancel('mission-1', reason: 'Too late.'),
        throwsA(
          isA<MissionControlNotAllowedException>().having(
            (MissionControlNotAllowedException e) => e.message,
            'message',
            contains('cannot be cancelled'),
          ),
        ),
      );
    });

    test('a 404 on cancel is not-found', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.notFound, <String, Object?>{
          'code': 'not_found',
          'message': 'No such mission.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).cancel('does-not-exist', reason: 'Gone.'),
        throwsA(isA<MissionNotFoundException>()),
      );
    });
  });

  group('explain', () {
    test('parses the server\'s explanation', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/missions/mission-1/explain');
        writeJson(request.response, HttpStatus.ok, <String, Object?>{
          'missionId': 'mission-1',
          'state': 'failed',
          'stage': 'done',
          'risk': 'controlled_write',
          'blocked': false,
          'blockedReason': null,
          'reasons': <String>['The executor reported an error.'],
          'lastError': 'boom',
          'recentStderr': <Object?>[
            <String, Object?>{'offset': 0, 'line': 'boom', 'at': '2026-08-20T10:00:00Z'},
          ],
          'generatedAt': '2026-08-20T10:10:00Z',
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final MissionExplanation explanation = await repositoryFor(server).explain('mission-1');

      expect(explanation.missionId, 'mission-1');
      expect(explanation.reasons, <String>['The executor reported an error.']);
      expect(explanation.lastError, 'boom');
      expect(explanation.recentStderr, hasLength(1));
      expect(explanation.recentStderr.single.line, 'boom');
    });

    test('a 404 is not-found', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.notFound, <String, Object?>{
          'code': 'not_found',
          'message': 'No such mission.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repositoryFor(server).explain('does-not-exist'),
        throwsA(isA<MissionNotFoundException>()),
      );
    });
  });
}
