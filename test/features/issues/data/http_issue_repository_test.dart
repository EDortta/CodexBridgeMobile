@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/features/issues/data/http_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpIssueRepository] against a real, locally bound
/// [HttpServer] — the same reasoning `http_auth_gateway_test.dart`'s own doc
/// comment gives: plain HTTP to `127.0.0.1`, no TLS, still exercises the
/// actual `dart:io` request/response round trip this class owns.
///
/// `not validated:` certificate handling — same carve-out
/// `http_auth_gateway_test.dart` documents, for the same reason.
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

  void writeError(
    HttpResponse response,
    int statusCode, {
    String code = 'internal_error',
    String message = 'Something went wrong.',
  }) {
    writeJson(response, statusCode, <String, Object?>{
      'code': code,
      'message': message,
      'requestId': 'req-1',
      'retryable': false,
    });
  }

  GatewayContext contextFor(HttpServer server) => GatewayContext(
    server: Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    ),
    accessToken: 'a-valid-access-token',
  );

  HttpIssueRepository repoFor(
    HttpServer server, {
    Duration timeout = const Duration(seconds: 5),
  }) => HttpIssueRepository(
    () async => contextFor(server),
    timeout: timeout,
  );

  Map<String, Object?> projectRow(String id) => <String, Object?>{
    'id': id,
    'name': id,
  };

  Map<String, Object?> epicRow({
    required String id,
    required String projectId,
    String title = 'An epic',
    String status = 'in_progress',
    String? description,
  }) => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'title': title,
    'description': description,
    'status': status,
    'revision': 3,
    'createdAt': '2026-08-20T10:00:00Z',
    'updatedAt': '2026-08-20T10:00:00Z',
    'createdBy': 'esteban@example.com',
    'updatedBy': null,
  };

  Map<String, Object?> issueRow({
    required String id,
    required String projectId,
    String? epicId,
    String title = 'An issue',
    String status = 'open',
    String priority = 'high',
    List<String> labels = const <String>[],
    String? assigneeUserId,
    String? assigneeEmail,
    List<String> dependencies = const <String>[],
    String? blockedReason,
    int revision = 5,
  }) => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'epicId': epicId,
    'title': title,
    'description': null,
    'status': status,
    'priority': priority,
    'labels': labels,
    'assigneeUserId': assigneeUserId,
    'assigneeEmail': assigneeEmail,
    'dependencies': dependencies,
    'blockedReason': blockedReason,
    'revision': revision,
    'createdAt': '2026-08-19T09:00:00Z',
    'updatedAt': '2026-08-19T09:00:00Z',
    'createdBy': 'esteban@example.com',
    'updatedBy': null,
  };

  Map<String, Object?> page(
    List<Map<String, Object?>> items, {
    bool hasMore = false,
    String? nextCursor,
  }) => <String, Object?>{
    'items': items,
    'page': <String, Object?>{'hasMore': hasMore, 'nextCursor': nextCursor},
  };

  group('loadIssues', () {
    test(
      'fans out across every visible project, following each list\'s cursor',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          final Uri uri = request.uri;
          if (uri.path == '/api/v1/projects') {
            if (uri.queryParameters['cursor'] == null) {
              writeJson(
                request.response,
                HttpStatus.ok,
                page(<Map<String, Object?>>[
                  projectRow('proj-a'),
                ], hasMore: true, nextCursor: 'p2'),
              );
            } else {
              writeJson(
                request.response,
                HttpStatus.ok,
                page(<Map<String, Object?>>[projectRow('proj-b')]),
              );
            }
            await request.response.close();
            return;
          }
          if (uri.path == '/api/v1/projects/proj-a/issues') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[
                issueRow(
                  id: 'issue-1',
                  projectId: 'proj-a',
                  assigneeEmail: 'op@example.com',
                ),
              ]),
            );
            await request.response.close();
            return;
          }
          if (uri.path == '/api/v1/projects/proj-b/issues') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[
                issueRow(
                  id: 'issue-2',
                  projectId: 'proj-b',
                  status: 'in_review',
                  priority: 'urgent',
                  assigneeUserId: 'user-9',
                ),
              ]),
            );
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final List<ProjectIssue> issues = await repoFor(server).loadIssues();

        expect(issues.map((ProjectIssue i) => i.id), <String>[
          'issue-1',
          'issue-2',
        ]);
        expect(issues[0].assignee, 'op@example.com');
        expect(
          issues[1].assignee,
          'user-9',
          reason: 'assigneeEmail absent, so assigneeUserId is the fallback',
        );
        expect(
          issues[1].status,
          IssueStatus.inProgress,
          reason: 'the wire\'s in_review folds into inProgress',
        );
        expect(
          issues[1].priority,
          IssuePriority.critical,
          reason: 'the wire\'s urgent renames to critical',
        );
      },
    );

    test('a 401 from the gateway surfaces the server message', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeError(
          request.response,
          HttpStatus.unauthorized,
          code: 'unauthenticated',
          message: 'This access token is no longer valid.',
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repoFor(server).loadIssues(),
        throwsA(
          isA<IssueRepositoryException>().having(
            (IssueRepositoryException e) => e.message,
            'message',
            'This access token is no longer valid.',
          ),
        ),
      );
    });

    test('no signed-in session is refused before any request', () async {
      final HttpIssueRepository repository = HttpIssueRepository(
        () async => null,
      );

      await expectLater(
        repository.loadIssues(),
        throwsA(isA<IssueRepositoryException>()),
      );
    });

    test('a connection that never answers is a bounded timeout', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        // Never writes a response — the client's own bound must fire.
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repoFor(
          server,
          timeout: const Duration(milliseconds: 80),
        ).loadIssues(),
        throwsA(
          isA<IssueRepositoryException>().having(
            (IssueRepositoryException e) => e.message,
            'message',
            contains('took too long'),
          ),
        ),
      );
    });

    test(
      'a connection that cannot be opened is reported, not thrown raw',
      () async {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final int deadPort = server.port;
        await server.close(force: true);
        final HttpIssueRepository repository = HttpIssueRepository(
          () async => GatewayContext(
            server: Uri(
              scheme: 'http',
              host: InternetAddress.loopbackIPv4.address,
              port: deadPort,
            ),
            accessToken: 'token',
          ),
        );

        await expectLater(
          repository.loadIssues(),
          throwsA(isA<IssueRepositoryException>()),
        );
      },
    );

    test('a response that is not JSON is reported, not thrown raw', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('not json at all {{{');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repoFor(server).loadIssues(),
        throwsA(
          isA<IssueRepositoryException>().having(
            (IssueRepositoryException e) => e.message,
            'message',
            contains('not JSON'),
          ),
        ),
      );
    });
  });

  group('loadEpics', () {
    test(
      'derives issueIds from each project\'s issues and drops the missing priority',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          final String path = request.uri.path;
          if (path == '/api/v1/projects') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[projectRow('proj-a')]),
            );
          } else if (path == '/api/v1/projects/proj-a/issues') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[
                issueRow(id: 'issue-1', projectId: 'proj-a', epicId: 'epic-1'),
                issueRow(id: 'issue-2', projectId: 'proj-a', epicId: 'epic-1'),
                issueRow(id: 'issue-3', projectId: 'proj-a'),
              ]),
            );
          } else if (path == '/api/v1/projects/proj-a/epics') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[
                epicRow(
                  id: 'epic-1',
                  projectId: 'proj-a',
                  description: 'Groups issue-1 and issue-2.',
                ),
              ]),
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final List<Epic> epics = await repoFor(server).loadEpics();

        expect(epics, hasLength(1));
        expect(epics.single.id, 'epic-1');
        expect(epics.single.issueIds, <String>['issue-1', 'issue-2']);
        expect(epics.single.summary, 'Groups issue-1 and issue-2.');
        expect(
          epics.single.priority,
          isNull,
          reason: 'the gateway epic has no priority column',
        );
        expect(
          epics.single.isBlocked,
          isFalse,
          reason: 'the gateway has no blocked epic status',
        );
      },
    );
  });

  group('loadIssue', () {
    test('loads a single issue directly by id', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.uri.path, '/api/v1/issues/issue-1');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer a-valid-access-token',
        );
        writeJson(
          request.response,
          HttpStatus.ok,
          issueRow(id: 'issue-1', projectId: 'proj-a', revision: 7),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final ProjectIssue issue = await repoFor(server).loadIssue('issue-1');

      expect(issue.id, 'issue-1');
      expect(issue.revision, 7);
    });

    test(
      'a 404 — the gateway\'s answer for both "does not exist" and "not in '
      'your visible projects" — is IssueNotFoundException, never a bare '
      'transport failure',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeError(
            request.response,
            HttpStatus.notFound,
            code: 'not_found',
            message: 'No such issue.',
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repoFor(server).loadIssue('someone-elses-issue'),
          throwsA(isA<IssueNotFoundException>()),
        );
      },
    );
  });

  group('loadEpic', () {
    test('searches each visible project until it finds a match', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        final String path = request.uri.path;
        if (path == '/api/v1/projects') {
          writeJson(
            request.response,
            HttpStatus.ok,
            page(<Map<String, Object?>>[
              projectRow('proj-a'),
              projectRow('proj-b'),
            ]),
          );
        } else if (path == '/api/v1/projects/proj-a/epics') {
          writeJson(request.response, HttpStatus.ok, page(<Map<String, Object?>>[]));
        } else if (path == '/api/v1/projects/proj-a/issues') {
          writeJson(request.response, HttpStatus.ok, page(<Map<String, Object?>>[]));
        } else if (path == '/api/v1/projects/proj-b/epics') {
          writeJson(
            request.response,
            HttpStatus.ok,
            page(<Map<String, Object?>>[
              epicRow(id: 'epic-9', projectId: 'proj-b'),
            ]),
          );
        } else if (path == '/api/v1/projects/proj-b/issues') {
          writeJson(
            request.response,
            HttpStatus.ok,
            page(<Map<String, Object?>>[
              issueRow(id: 'issue-1', projectId: 'proj-b', epicId: 'epic-9'),
            ]),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Epic epic = await repoFor(server).loadEpic('epic-9');

      expect(epic.projectId, 'proj-b');
      expect(epic.issueIds, <String>['issue-1']);
    });

    test(
      'absent from every visible project is EpicNotFoundException',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          if (request.uri.path == '/api/v1/projects') {
            writeJson(
              request.response,
              HttpStatus.ok,
              page(<Map<String, Object?>>[projectRow('proj-a')]),
            );
          } else {
            writeJson(request.response, HttpStatus.ok, page(<Map<String, Object?>>[]));
          }
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repoFor(server).loadEpic('nowhere-to-be-found'),
          throwsA(isA<EpicNotFoundException>()),
        );
      },
    );
  });

  group('createEpic', () {
    test('posts the epic and reads back the created record', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/epics');
        final Map<String, Object?> sent =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(sent['projectId'], 'proj-a');
        expect(sent['title'], 'A new epic');
        expect(sent['status'], 'open');
        writeJson(
          request.response,
          HttpStatus.created,
          epicRow(id: 'epic-new', projectId: 'proj-a', status: 'open'),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final Epic epic = await repoFor(server).createEpic(
        projectId: 'proj-a',
        title: 'A new epic',
        status: IssueStatus.todo,
      );

      expect(epic.id, 'epic-new');
      expect(epic.status, IssueStatus.todo);
    });
  });

  group('createIssue', () {
    test('posts the issue and reads back the created record', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/issues');
        final Map<String, Object?> sent =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(sent['projectId'], 'proj-a');
        expect(sent['epicId'], 'epic-1');
        expect(sent['priority'], 'urgent');
        writeJson(
          request.response,
          HttpStatus.created,
          issueRow(
            id: 'issue-new',
            projectId: 'proj-a',
            epicId: 'epic-1',
            priority: 'urgent',
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final ProjectIssue issue = await repoFor(server).createIssue(
        projectId: 'proj-a',
        title: 'A new issue',
        epicId: 'epic-1',
        priority: IssuePriority.critical,
      );

      expect(issue.id, 'issue-new');
      expect(issue.priority, IssuePriority.critical);
    });
  });

  group('updateIssue', () {
    test('sends If-Match and applies the change', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/api/v1/issues/issue-1');
        expect(request.headers.value(HttpHeaders.ifMatchHeader), '"5"');
        final Map<String, Object?> sent =
            jsonDecode(await bodyOf(request)) as Map<String, Object?>;
        expect(sent['status'], 'blocked');
        expect(sent['blockedReason'], 'Waiting on review.');
        writeJson(
          request.response,
          HttpStatus.ok,
          issueRow(
            id: 'issue-1',
            projectId: 'proj-a',
            status: 'blocked',
            blockedReason: 'Waiting on review.',
            revision: 6,
          ),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final ProjectIssue issue = await repoFor(server).updateIssue(
        issueId: 'issue-1',
        revision: 5,
        status: IssueStatus.blocked,
        blockedReason: 'Waiting on review.',
      );

      expect(issue.status, IssueStatus.blocked);
      expect(issue.revision, 6);
    });

    test(
      'a stale revision is StaleIssueRevisionException, the gateway\'s 412',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(request.response, HttpStatus.preconditionFailed, <String, Object?>{
            'code': 'stale_write',
            'message':
                'This entity changed since you read it. Re-read it, show the '
                'current state, and let the operator decide again.',
            'requestId': 'req-1',
            'retryable': false,
          });
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        await expectLater(
          repoFor(server).updateIssue(issueId: 'issue-1', revision: 5, status: IssueStatus.done),
          throwsA(isA<StaleIssueRevisionException>()),
        );
      },
    );
  });

  group('linkIssueToEpic', () {
    test('sends If-Match against the issue revision and returns it', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/epics/epic-1/issues/issue-1');
        expect(request.headers.value(HttpHeaders.ifMatchHeader), '"5"');
        writeJson(
          request.response,
          HttpStatus.ok,
          issueRow(id: 'issue-1', projectId: 'proj-a', epicId: 'epic-1', revision: 6),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final ProjectIssue issue = await repoFor(server).linkIssueToEpic(
        epicId: 'epic-1',
        issueId: 'issue-1',
        issueRevision: 5,
      );

      expect(issue.epicId, 'epic-1');
      expect(issue.revision, 6);
    });

    test('a stale revision is StaleIssueRevisionException', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.preconditionFailed, <String, Object?>{
          'code': 'stale_write',
          'message': 'This entity changed since you read it.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        repoFor(
          server,
        ).linkIssueToEpic(epicId: 'epic-1', issueId: 'issue-1', issueRevision: 1),
        throwsA(isA<StaleIssueRevisionException>()),
      );
    });
  });
}
