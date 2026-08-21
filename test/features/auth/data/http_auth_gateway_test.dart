@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_bridge_mobile/features/auth/data/http_auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [HttpAuthGateway] against a real, locally bound [HttpServer] —
/// no TLS, so no self-signed key to commit (`security-standards.md` §1
/// forbids that even for a test; it is why `HttpServerProbeTest` stops at the
/// pure transport-failure mapping instead). Plain HTTP to `127.0.0.1` still
/// exercises the actual `dart:io` request/response round trip this class
/// owns: the JSON it sends, the headers it sets, and the shapes it accepts or
/// rejects from a real socket — not a mock of one.
///
/// `not validated:` certificate handling. [HttpAuthGateway] installs no
/// `badCertificateCallback` and disables none of `HttpClient`'s defaults, so
/// TLS verification is exactly what `dart:io` does out of the box — the same
/// property [HttpServerProbe] relies on and the same reason its own test
/// cannot exercise the socket either.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 21, 12);

  Session grantedSession() => Session(
    accessToken: 'stored-access-token',
    refreshToken: 'stored-refresh-token',
    expiresAt: now.add(const Duration(hours: 1)),
    refreshExpiresAt: now.add(const Duration(days: 7)),
    operatorId: 'operator-1',
    operatorName: 'Operator One',
  );

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

  Map<String, Object?> tokensBody({
    String accessToken = 'fresh-access-token',
    String refreshToken = 'fresh-refresh-token',
    int expiresIn = 900,
    String refreshTokenExpiresAt = '2026-08-28T12:00:00Z',
  }) => <String, Object?>{
    'tokenType': 'Bearer',
    'accessToken': accessToken,
    'accessTokenExpiresAt': '2026-08-21T12:15:00Z',
    'expiresIn': expiresIn,
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': refreshTokenExpiresAt,
    'scopes': <String>['project.read'],
  };

  HttpAuthGateway gatewayFor(HttpServer server, {DateTime Function()? now}) =>
      HttpAuthGateway(
        () async => Uri(
          scheme: 'http',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
        now ?? () => DateTime.utc(2026, 8, 21, 12),
      );

  group('signIn', () {
    test(
      'a blank username or password is refused before any request is sent',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          fail('a blank credential must not reach the network');
        });
        addTearDown(() => server.close(force: true));
        final HttpAuthGateway gateway = gatewayFor(server);

        final AuthOutcome usernameBlank = await gateway.signIn(
          username: '   ',
          password: 'a-password',
        );
        final AuthOutcome passwordBlank = await gateway.signIn(
          username: 'an-operator',
          password: '',
        );

        expect(
          (usernameBlank as AuthDenied).reason,
          AuthFailure.missingCredential,
        );
        expect(
          (passwordBlank as AuthDenied).reason,
          AuthFailure.missingCredential,
        );
      },
    );

    test('a granted sign-in resolves identity through /auth/me', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/auth/sign-in') {
          final Map<String, Object?> body =
              jsonDecode(await bodyOf(request)) as Map<String, Object?>;
          expect(body['username'], 'an-operator');
          expect(body['password'], 'a-password');
          writeJson(request.response, HttpStatus.ok, tokensBody());
          await request.response.close();
          return;
        }
        if (request.method == 'GET' && request.uri.path == '/api/v1/auth/me') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer fresh-access-token',
          );
          writeJson(request.response, HttpStatus.ok, <String, Object?>{
            'actor': <String, Object?>{
              'kind': 'user',
              'id': 'esteban',
              'email': 'esteban@example.com',
            },
            'roles': <String>['operator'],
            'scopes': <String>['project.read'],
            'projects': <String, Object?>{'all': true, 'ids': <String>[]},
            'permissions': <Object?>[],
            'authScheme': 'oauth',
            'generatedAt': '2026-08-21T12:00:00Z',
          });
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final HttpAuthGateway gateway = gatewayFor(server);

      final AuthOutcome outcome = await gateway.signIn(
        username: 'an-operator',
        password: 'a-password',
      );

      final Session session = (outcome as AuthGranted).session;
      expect(session.accessToken, 'fresh-access-token');
      expect(session.refreshToken, 'fresh-refresh-token');
      expect(session.expiresAt, now.add(const Duration(seconds: 900)));
      expect(session.refreshExpiresAt, DateTime.parse('2026-08-28T12:00:00Z'));
      expect(session.operatorId, 'esteban');
      expect(
        session.operatorName,
        'esteban@example.com',
        reason: 'no displayName in the response, so email is the fallback',
      );
    });

    test('a 401 from sign-in is a rejected credential', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(request.response, HttpStatus.unauthorized, <String, Object?>{
          'code': 'unauthenticated',
          'message': 'Sign-in failed.',
          'requestId': 'req-1',
          'retryable': false,
        });
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final HttpAuthGateway gateway = gatewayFor(server);

      final AuthOutcome outcome = await gateway.signIn(
        username: 'an-operator',
        password: 'wrong-password',
      );

      expect((outcome as AuthDenied).reason, AuthFailure.rejectedCredential);
    });

    test('a 422 from sign-in is also a rejected credential', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        writeJson(
          request.response,
          HttpStatus.unprocessableEntity,
          <String, Object?>{
            'code': 'validation_failed',
            'message': 'The request was malformed.',
            'requestId': 'req-1',
            'retryable': false,
          },
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final HttpAuthGateway gateway = gatewayFor(server);

      final AuthOutcome outcome = await gateway.signIn(
        username: 'an-operator',
        password: 'wrong-password',
      );

      expect((outcome as AuthDenied).reason, AuthFailure.rejectedCredential);
    });

    test(
      'a connection that cannot be opened is reported as unreachable',
      () async {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final int deadPort = server.port;
        await server.close(force: true);
        final HttpAuthGateway gateway = HttpAuthGateway(
          () async => Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: deadPort,
          ),
          () => now,
        );

        final AuthOutcome outcome = await gateway.signIn(
          username: 'an-operator',
          password: 'a-password',
        );

        expect((outcome as AuthDenied).reason, AuthFailure.unreachable);
      },
    );

    test(
      'no server selected is reported as unreachable, never a throw',
      () async {
        final HttpAuthGateway gateway = HttpAuthGateway(
          () async => null,
          () => now,
        );

        final AuthOutcome outcome = await gateway.signIn(
          username: 'an-operator',
          password: 'a-password',
        );

        expect((outcome as AuthDenied).reason, AuthFailure.unreachable);
      },
    );

    test(
      'a grant issued but never identified is refused, not shown half-built',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          if (request.uri.path == '/api/v1/auth/sign-in') {
            writeJson(request.response, HttpStatus.ok, tokensBody());
            await request.response.close();
            return;
          }
          // /auth/me fails: the grant exists but this device cannot learn whose
          // it is.
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final HttpAuthGateway gateway = gatewayFor(server);

        final AuthOutcome outcome = await gateway.signIn(
          username: 'an-operator',
          password: 'a-password',
        );

        expect(
          (outcome as AuthDenied).reason,
          AuthFailure.unreachable,
          reason:
              'Session.operatorId must never be guessed from client input, so a '
              'token this device cannot attribute must not become a session',
        );
      },
    );
  });

  group('renew', () {
    test(
      'a granted renewal carries the operator forward without calling /auth/me',
      () async {
        bool meWasCalled = false;
        final HttpServer server = await serve((HttpRequest request) async {
          if (request.method == 'POST' &&
              request.uri.path == '/api/v1/auth/refresh') {
            final Map<String, Object?> body =
                jsonDecode(await bodyOf(request)) as Map<String, Object?>;
            expect(body['refreshToken'], 'stored-refresh-token');
            writeJson(
              request.response,
              HttpStatus.ok,
              tokensBody(
                accessToken: 'renewed-access-token',
                refreshToken: 'renewed-refresh-token',
              ),
            );
            await request.response.close();
            return;
          }
          if (request.uri.path == '/api/v1/auth/me') {
            meWasCalled = true;
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final HttpAuthGateway gateway = gatewayFor(server);

        final AuthOutcome outcome = await gateway.renew(grantedSession());

        final Session renewed = (outcome as AuthGranted).session;
        expect(renewed.accessToken, 'renewed-access-token');
        expect(renewed.refreshToken, 'renewed-refresh-token');
        expect(renewed.expiresAt, now.add(const Duration(seconds: 900)));
        expect(renewed.operatorId, 'operator-1');
        expect(renewed.operatorName, 'Operator One');
        expect(
          meWasCalled,
          isFalse,
          reason:
              'a renewal is the same actor; it must not cost a second round trip',
        );
      },
    );

    test(
      'a 401 from refresh means the session can no longer be renewed',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          writeJson(
            request.response,
            HttpStatus.unauthorized,
            <String, Object?>{
              'code': 'unauthenticated',
              'message': 'The credential is not valid.',
              'requestId': 'req-1',
              'retryable': false,
            },
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final HttpAuthGateway gateway = gatewayFor(server);

        final AuthOutcome outcome = await gateway.renew(grantedSession());

        expect(
          (outcome as AuthDenied).reason,
          AuthFailure.sessionNoLongerRenewable,
        );
      },
    );

    test(
      'a connection failure during renewal is unreachable, not a throw',
      () async {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final int deadPort = server.port;
        await server.close(force: true);
        final HttpAuthGateway gateway = HttpAuthGateway(
          () async => Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: deadPort,
          ),
          () => now,
        );

        final AuthOutcome outcome = await gateway.renew(grantedSession());

        expect((outcome as AuthDenied).reason, AuthFailure.unreachable);
      },
    );
  });

  group('revoke', () {
    test(
      'sends the access token and the refresh token, and reports success',
      () async {
        final HttpServer server = await serve((HttpRequest request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/api/v1/auth/revoke');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer stored-access-token',
          );
          final Map<String, Object?> body =
              jsonDecode(await bodyOf(request)) as Map<String, Object?>;
          expect(body['refreshToken'], 'stored-refresh-token');
          writeJson(request.response, HttpStatus.ok, <String, Object?>{
            'revoked': true,
            'revokedAt': '2026-08-21T12:00:00Z',
            'accessTokensRevoked': 1,
            'refreshTokensRevoked': 1,
          });
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final HttpAuthGateway gateway = gatewayFor(server);

        final bool revoked = await gateway.revoke(grantedSession());

        expect(revoked, isTrue);
      },
    );

    test('a refused revoke reports false rather than throwing', () async {
      final HttpServer server = await serve((HttpRequest request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final HttpAuthGateway gateway = gatewayFor(server);

      final bool revoked = await gateway.revoke(grantedSession());

      expect(revoked, isFalse);
    });

    test('no server selected reports false rather than throwing', () async {
      final HttpAuthGateway gateway = HttpAuthGateway(
        () async => null,
        () => now,
      );

      expect(await gateway.revoke(grantedSession()), isFalse);
    });
  });
}
